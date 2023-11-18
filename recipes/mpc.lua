local lgi = require "lgi"
local GLib = lgi.GLib
local Gio = lgi.Gio

local gears = require "gears"

local mpc = {}

local function parse_password(host)
	-- This function is based on mpd_parse_host_password() from libmpdclient
	local position = string.find(host, "@")
	if not position then
		return host
	end
	return string.sub(host, position + 1), string.sub(host, 1, position - 1)
end

function mpc.new(host, port, password, error_handler, reconnect_interval, ...)
	host = host or os.getenv("MPD_HOST") or "localhost"
	port = port or os.getenv("MPD_PORT") or 6600
	if not password then
		host, password = parse_password(host)
	end

	local self = setmetatable({
		_host = host,
		_port = port,
		_password = password,
		_error_handler = error_handler or function() end,
		_connected = false,
		_idle_commands = { ... },
		_conn = nil,
		_output = nil,
		_input = nil,
		_reconnect_timer = nil,
		_reconnect_interval = reconnect_interval,
		_try_reconnect = true
	}, { __index = mpc })

	self:_connect()
	return self
end

function mpc:_error(err)
	self._error_handler(err, self)
end

function mpc:_reset()
	self._output = nil
	self._input = nil
	self._reply_handlers = {}
	self._pending_reply = {}
	self._idle_commands_pending = false
	self._idle = false
	self._connected = false
end

function mpc:_reconnect()
	if not self._reconnect_timer then
		self:_error("cannot reconnect")
		return
	end

	if not self._try_reconnect then
		return
	end

	self._reconnect_timer:again()
end

function mpc:_connect()
	if self._connected then return end
	-- Reset all of our state
	self:_reset()

	-- Set up a new connection
	local address
	if string.sub(self._host, 1, 1) == "/" then
		-- It's a unix socket
		address = Gio.UnixSocketAddress.new(self._host)
	else
		-- Do a TCP connection
		address = Gio.NetworkAddress.new(self._host, self._port)
	end
	local client = Gio.SocketClient()

	local conn
	if not self._conn then
		if not self._reconnect_timer and self._try_reconnect then
			-- timer requires positive value
			local interval = self._reconnect_interval >= 0 and self._reconnect_interval or 0
			self._reconnect_timer = gears.timer.start_new(interval, function()
				-- user disabled reconnect
				if self._reconnect_interval < 0 then
					self._try_reconnect = false
				end

				self:_reset()
				conn, err = client:connect(address)

				if not conn then
					self:_error(err)
					return true
				end

				self._connected = true

				local input, output = conn:get_input_stream(), conn:get_output_stream()
				self._conn, self._output, self._input = conn, output, Gio.DataInputStream.new(input)

				-- Read the welcome message
				self._input:read_line()

				if self._password and self._password ~= "" then
					self:_send("password " .. self._password)
				end

				return false
			end)
		else
			self:_reconnect()
		end
	end

	self._reconnect_timer:connect_signal("stop", function()
		self:do_read()
		-- To synchronize the state on startup, send the idle commands now. As a
		-- side effect, this will enable idle state.
		self:_send_idle_commands(true)
	end)
end

function mpc:do_read()
	-- Set up the reading loop. This will asynchronously read lines by
	-- calling itself.
	self._input:read_line_async(GLib.PRIORITY_DEFAULT, nil, function(obj, res)
		local line, err = obj:read_line_finish(res)
		-- Ugly API. On success we get string, length-of-string
		-- and on error we get nil, error. Other versions of lgi
		-- behave differently.
		if line == nil or tostring(line) == "" then
			err = "Connection closed"
			self:_error(err)
			self:_reconnect()
			return
		end

		if type(err) ~= "number" then
			self:_error(err)
			self:_reconnect()
		else
			self:do_read()
			line = tostring(line)
			if line == "OK" or line:match("^ACK ") then
				local success = line == "OK"
				local arg
				if success then
					arg = self._pending_reply
				else
					arg = { line }
				end
				local handler = self._reply_handlers[1]
				table.remove(self._reply_handlers, 1)
				self._pending_reply = {}
				handler(success, arg)
			else
				local _, _, key, value = string.find(line, "([^:]+):%s(.+)")
				if key then
					self._pending_reply[string.lower(key)] = value
				end
			end
		end
	end)
end

function mpc:_send_idle_commands(skip_stop_idle)
	-- We use a ping to unset this to make sure we never get into a busy
	-- loop sending idle / unidle commands. Next call to
	-- _send_idle_commands() might be ignored!
	if self._idle_commands_pending then
		return
	end
	if not skip_stop_idle then
		self:_stop_idle()
	end

	self._idle_commands_pending = true
	for i = 1, #self._idle_commands, 2 do
		self:_send(self._idle_commands[i], self._idle_commands[i+1])
	end
	self:_send("ping", function()
		self._idle_commands_pending = false
	end)
	self:_start_idle()
end

function mpc:_start_idle()
	if self._idle then
		self:_error("still idle?!")
		error("Still idle?!")
	end
	self:_send("idle", function(success, reply)
		if reply.changed then
			-- idle mode was disabled by mpd
			self:_send_idle_commands()
		end
	end)
	self._idle = true
end

function mpc:_stop_idle()
	if not self._idle then
		self:_error("Not idle?!")
		error("Not idle?!")
	end
	self._output:write("noidle\n")
	self._idle = false
end

function mpc:_send(command, callback)
	if self._idle then
		self:_error("Still idle in send()?!")
		error("Still idle in send()?!")
	end
	self._output:write(command .. "\n")
	table.insert(self._reply_handlers, callback or function() end)
end

function mpc:send(...)
	if not self._conn then
		self:_reconnect()
		return
	end

	local args = { ... }
	if not self._idle then
		self:_error("Something is messed up, we should be idle here...")
		error("Something is messed up, we should be idle here...")
	end
	self:_stop_idle()
	for i = 1, #args, 2 do
		self:_send(args[i], args[i+1])
	end
	self:_start_idle()
end

function mpc:toggle_play()
	self:send("status", function(success, status)
		if status.state == "stop" then
			self:send("play")
		else
			self:send("pause")
		end
	end)
end

--[[

-- Example on how to use this (standalone)
-- set negative reconnect_interval to disable reconnect in case initial connection failed

local host, port, password, reconnect_interval = nil, nil, nil, 0
local m = mpc.new(host, port, password, error_handler, reconnect_interval
	"status", function(success, status) print("status is", status.state) end)

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, function()
	-- Test command submission
	m:send("status", function(_, s) print(s.state) end,
		"currentsong", function(_, s) print(s.title) end)
	m:send("status", function(_, s) print(s.state) end)
	-- Force a reconnect
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, function()
		m._conn:close()
	end)
end)

GLib.MainLoop():run()
--]]

return mpc
