--- Manage sending SIGSTOP/SIGCONT signals to special clients when they are
-- (un)focused.
--
-- Clients with ontop = true are ignored.
--
-- You can add a client to sigstop_unfocus.ignore_clients to ignore it:
--
--     stop_unfocused.ignore_clients[c] = true
--
-- To not ignore it anymore, unset it:
--
--     stop_unfocused.ignore_clients[c] = nil
--
-- IDEA: Slack: stop it in general, but wake up in intervals (e.g. every
-- minute), unless focused.
--
-- CAVEATS:
--
-- 1. requires to continue an application that should handle links, e.g.
--    browsers when clicking an URL somewhere else, and mail programs when using
--    mailto links from a browser.
--    This can be achieved using a wrapper script, e.g. `~/bin/firefox`, which
--    would send SIGCONT to Firefox if stopped, and then call
--    `/usr/bin/firefox`.
--    helper for awesome-client: use client.pid to read /proc/$PID/exe, and get
--    client(s) for given exe.  But can just use "kill -CONT $PID" then in the
--    wrapper script.

local gears = require('gears')
local timer = require('gears.timer')

local naughty = require('naughty')

--- Print a log message.
-- @tparam string message The message to print.
local function log(...)
  local args = {...}
  local msg
  if #args == 1 then
    msg = args[1]
  else
    local sliced = {}
    for i = 2, #args, 1 do
      sliced[#sliced + 1] = args[i]
    end
    msg = gears.debug.dump_return(sliced, args[1])
  end
  io.stderr:write(os.date("%Y-%m-%d %T stop_unfocused: ") .. tostring(msg) .. "\n")
end

local awful = require('awful')
local function get_props_and_callbacks(c, _rules)
    local matching_rules = awful.rules.matching_rules(c, _rules)
    if #matching_rules == 0 then
        return
    end

    local props = {}
    local callbacks = {}
    for _, entry in ipairs(matching_rules) do
        gears.table.crush(props, entry.properties or {})
        if entry.callback then
            table.insert(callbacks, entry.callback)
        end
    end
    return props, callbacks
end

-- A table of stopped client PIDs as key, and a table with config/props as
-- values.
-- TODO: do not store callbacks as values, but get them when needed for sigcont.
-- (they are not persisted when restarting)
local sigstopped_pids = {}

-- The module's table.
local stop_unfocused = {}

stop_unfocused.config = {
  rules = {
    {rule = {class = 'qutebrowser'}, properties = {
      include_child_processes = true,
      pgrep_args = {'-f', 'QtWebEngineProc'},
    }},
    -- TODO: include_child_processes / pgrep_args
    {rule = {class = 'firefox'}},

    {rule = {class = 'Thunderbird'}, properties = {
      -- No childs (e.g. PDF viewer).
      include_child_processes = false,
    }},

    -- Do not stop clients showing a dialog (Thunderbird's "Sending Message").
    {rule = {type = "dialog"}, properties = {
      stop_timeout = false,
    }},

    -- Do not stop clients with ontop=true.
    {rule = {ontop = true}, properties = {
      stop_timeout = false,
    }},
  },

  -- Default settings.

  -- Timeout for stopping an unfocused client.
  stop_timeout = 30,

  -- Include child processes?  This uses `pgrep` to get those.
  -- You can use `pgrep_args` for filterting them.
  include_child_processes = true,

  -- Extra args for `pgrep` with `include_child_processes`.
  -- This can be used to filter/handle only certain child processes.
  pgrep_args = nil,

  -- stop_callback = stop_unfocused.sigstop,
  -- cont_callback = stop_unfocused.sigcont,

  -- Timer delay for delayed focus handler, used to compare if the mouse has
  -- not moved inbetween.
  delayed_focus_timeout = 0.05,
}

stop_unfocused.ignore_clients = {}

stop_unfocused.notify = function(msg)
  naughty.notify({
    text = string.format('%s (%d total stopped)', msg, #gears.table.keys(sigstopped_pids)),
    timeout = 5
  })
end

stop_unfocused.handle_clipboard_cmd = {
  awful.util.shell, '-c',
  -- 'echo sleeping; sleep 5; echo slept'
  -- NOTE: sleep is necessary to ensure the client is not stopped before
  -- clipboard is taken over really.
  -- 'xclip -quiet -o -selection primary   | xclip -quiet -i -selection primary &; echo $!;'..
  -- 'xclip -quiet -o -selection clipboard | xclip -quiet -i -selection clipboard &; echo $!'
  -- ..'; sleep 1; echo exited'
  -- 2019-04-25: try xsel --keep instead.
  -- 'xclip -o -selection primary   | xclip -i -selection primary &'..
  -- 'xclip -o -selection clipboard | xclip -i -selection clipboard &'
  -- Only handles PRIMARY.
  -- 'xsel -vv --keep & '
  'copyq "copySelection(selection())" && copyq "copy(clipboard())"'

  -- accessing the clipboard might hang, wait for xclip to really take over.
  ..'; sleep 1'

}

--- Intermediate callback before stopping a client.
-- This is used to take ownership of the primary selection and clipboard.
stop_unfocused.pre_kill_stop_callback = function(kill_cb)
  log("pre_kill_stop_callback: running: " .. table.concat(stop_unfocused.handle_clipboard_cmd, ' '))
  -- local handled_clipboard = 0
  local pid_or_error = awful.spawn.with_line_callback(
    stop_unfocused.handle_clipboard_cmd,
    {
      exit = function()
        kill_cb()
      end,

      -- For debugging.
      stdout = function(line)
        log("handle_clipboard_cmd stdout: "..line)
      end,
      stderr = function(line)
        log("handle_clipboard_cmd stderr: "..line)
        -- log("handle_clipboard_cmd stderr ("..handled_clipboard.."): "..line)
        -- if (line == 'Waiting for selection requests, Control-C to quit'
        --     or line == 'Error: target STRING not available') then
        --   handled_clipboard = handled_clipboard + 1
        --   if handled_clipboard == 2 then
        --     log("kill_cb()")
        --     kill_cb()
        --   end
        -- end
      end,
    })
  log('pre_kill_stop_callback: pid_or_error='..pid_or_error)
  return pid_or_error
end

-- Active timers by PID.
local sigstop_timers = {}

-- @treturn[1] Integer the PID of the forked process.
-- @treturn[2] string Error message.
stop_unfocused.spawn_with_cb_on_exit = function(cmd, cb_on_exit)
  local spawn_cb = function(stdout, stderr, exitreason, exitcode)  --luacheck: no unused args
    log("spawn_cb for " .. table.concat(cmd, ' '))
    if stdout and stdout ~= '' then
      log('  stdout: ' .. stdout)
    end
    if stderr and stderr ~= '' then
      log('  stderr: ' .. stderr)
    end
    if exitreason == 'exit' then
      log('  exit: ' .. exitcode)
      log('  calling callback cb_on_exit: ' .. tostring(cb_on_exit)
          .. ' (args: '..tostring(exitcode) .. ')')
      return cb_on_exit(exitcode)
    end
  end

  log("spawn: " .. table.concat(cmd, ' '))
  return awful.spawn.easy_async(cmd, spawn_cb)
end

-- Get config for a client, merged with defaults.
local get_client_config = function(c)
  local props, callbacks = get_props_and_callbacks(c, stop_unfocused.config.rules)

  -- Merge with defaults.
  props = gears.table.join(stop_unfocused.config, props)

  return props, callbacks
end

stop_unfocused.sigstopped_pids = sigstopped_pids  -- for debugging.

-- Intermediate callback to get a client's child PIDs.
local function get_pids_for_kill_stop_cb(c, next_cb)
  log('get_pids_for_kill_stop_cb: '..c.pid)

  -- local include_child_processes = sigstop
  local config = sigstopped_pids[c.pid]
  if not config or not config.include_child_processes then
    return next_cb({c.pid})
  end

  local cmd = {awful.util.shell, '-c',
    'chpids() {'..
    '  local pids="$1"; shift;'..
    '  local childs="$(pgrep -P "$pids" "$@")";'..
    '  if [ -n "$childs" ]; then'..
    '    chpids "$(echo "$childs" | paste -s -d,)" "$@";'..
    '  fi;'..
    '};'..
    'chpids "$@"', '--', tostring(c.pid)}

  if config.pgrep_args then
    for _,v in pairs(config.pgrep_args) do
      table.insert(cmd, v)
    end
  end

  return awful.spawn.easy_async(cmd, function(stdout, stderr, _, exitcode)
    local pids
    if exitcode ~= 0 or stderr ~= "" then
      log(string.format("get_pids_for_kill_stop_cb cmd (%s) failed (%d): %s", table.concat(cmd, ' '), exitcode, stderr))
      pids = {}
    else
      pids = gears.string.split(stdout, '\n')
      pids[#pids] = nil
      log("get_pids_for_kill_stop_cb: "..#pids.." child pids")
    end
    table.insert(pids, c.pid)
    return next_cb(pids)
  end)
end

-- TODO: cleanup.. do not update via next_cb!?
local running_cbs = {}

--- Call the next callback from `queue` for client `c`.
-- The callback is called with args `c`, `stop` and `next_cb`, and needs to call
-- `next_cb` (without any args).
local function call_next_callback(c, stop, queue)
  local k, cb = next(queue)
  log('== call_next_callback: (' .. (stop and 'stop' or 'cont') .. ') ==', k, cb, stop)
  if stop and not sigstopped_pids[c.pid] then
    log('Aborting stop callbacks for continued client.')
    return
  end

  if cb then
    local function next_cb(cb_pid_or_error)
      if cb_pid_or_error ~= nil then
        log('updating running_cbs['..c.pid..']: '..cb_pid_or_error)
        log('1')
        if type(cb_pid_or_error) == 'string' then
          gears.debug.print_error('Failed to run callback: ' .. cb_pid_or_error)
        else
          running_cbs[c.pid] = cb_pid_or_error
        end
      elseif c.valid then
        log('== next_cb: '..c.pid..': stop='..tostring(stop)
            ..' #queue='..#queue..' cb_pid_or_error='..tostring(cb_pid_or_error))
        if running_cbs[c.pid] then
          log('Removing finished cb with PID '..tostring(running_cbs[c.pid]))
          awesome.kill(running_cbs[c.pid], awesome.unix_signal['SIGTERM'])
          running_cbs[c.pid] = nil
        end

        return call_next_callback(c, stop, queue)
      end
    end

    queue[k] = nil
    log('Calling callback '..tostring(cb), stop, c, next_cb)
    local maybe_pid = gears.protected_call(cb, c, stop, next_cb)
    log('Return from callback '..tostring(cb)..': ' .. tostring(maybe_pid))
    if type(maybe_pid) == 'number' then
      log('Got PID, adding to running_cbs: ' .. tostring(maybe_pid) .. '.')
      running_cbs[c.pid] = maybe_pid
    end
    return
  end
  log('callbacks done')
end

-- TODO: use props/config instead of callbacks, for when calling this manually,
-- and you do not want to stop child processes.
function stop_unfocused.sigstop(c, config)
  if not c.pid then
    log('sigstop: no PID for client: ' .. c.name)
    return
  end

  config = config or {}
  local props, callbacks = get_client_config(c)

  -- Explicit config, overrides props from rules.
  sigstopped_pids[c.pid] = {
    include_child_processes = config.include_child_processes ~= nil
      and config.include_child_processes or props.include_child_processes,
    pgrep_args = config.pgrep_args ~= nil
      and config.pgrep_args or props.pgrep_args,

    _child_pids = {},
  }
  log('SIGSTOP: marking stopped: '..c.pid)

  local function main_stop(_, _, next_cb)
    log('main_stop: '..c.pid)

    -- local pid_or_error = get_pids_for_kill_stop_cb(c, function(pids)
    get_pids_for_kill_stop_cb(c, function(pids)
      local kill_stop_cb = function()
        if not c.valid then
          log("kill_stop_cb: client not valid anymore, ignoring.")
        elseif not sigstopped_pids[c.pid] then
          log("kill_stop_cb: "..c.pid..": client not marked as stopped anymore!")
        else
          log(string.format("kill_stop_cb: %d: kill -STOP %d (%d PIDs)", c.pid, c.pid, #pids))
          -- stop_unfocused.notify(string.format('stopping %d (%d PIDs)', c.pid, #pids))
          for _,pid in pairs(pids) do
            awesome.kill(pid, awesome.unix_signal['SIGSTOP'])

            -- Remember child PID as stopped.
            if pid ~= c.pid then
              table.insert(sigstopped_pids[c.pid]._child_pids, pid)
            end
          end
        end
        next_cb()
      end

      next_cb(stop_unfocused.pre_kill_stop_callback(kill_stop_cb))
    end)
  end
  callbacks = gears.table.merge({main_stop}, callbacks or {})
  call_next_callback(c, true, callbacks)
end

-- Send SIGCONT to a client.
--
-- This will also handle clients not being stopped before, which is relevant
-- for config changes etc.
function stop_unfocused.sigcont(c)
  log(string.format("sigcont: %s", c.name))
  if not c.pid then
    log('sigcont: no PID for client: ' .. c.name)
    return
  end

  local child_pids
  if not sigstopped_pids[c.pid] then
    log(string.format('SIGCONT: NOTE: %d is not registered as stopped client (restart?)', c.pid))
    child_pids = {}
  else
    child_pids = sigstopped_pids[c.pid]._child_pids or {}
  end

  log(string.format('SIGCONT: %d: marking continued (%d childs)', c.pid, #child_pids))
  sigstopped_pids[c.pid] = nil

  if running_cbs[c.pid] then
    log('Killing cb with PID '..tostring(running_cbs[c.pid]))
    awesome.kill(running_cbs[c.pid], awesome.unix_signal['SIGTERM'])
    running_cbs[c.pid] = nil
  end

  local function main_cont(_, _, next_cb)
    log(string.format("kill_cont_cb: %d: kill -CONT %d", c.pid, c.pid))
    -- stop_unfocused.notify(string.format('continuing %d (%d PIDs)', c.pid, 1 + #child_pids))
    awesome.kill(c.pid, awesome.unix_signal['SIGCONT'])

    if #child_pids > 0 then
      log(string.format("kill_cont_cb: %d child PIDs", #child_pids))
      for _,pid in pairs(child_pids) do
        awesome.kill(pid, awesome.unix_signal['SIGCONT'])
      end
    end

    next_cb()
  end

  local _, callbacks = get_client_config(c)
  callbacks = gears.table.merge({main_cont}, callbacks or {})
  log(tostring(#callbacks) .. ' cont callbacks')

  call_next_callback(c, false, callbacks)
end

-- Helper function to be used in scripts wrapping browsers, email clients etc to
-- raise the client window (which also continues it then).
-- This is necessary for when opening links from other programs, while the
-- target program is stopped.
function stop_unfocused.raise_by_prop(rule)
  for _,c in pairs(client.get()) do
    if awful.rules.match(c, rule) then
      log(string.format("sigcont_by_prop: raising %d (%s)", c.pid, c.name))
      -- stop_unfocused.sigcont(c)
      -- c:raise()
      c:emit_signal('request::activate', "stop_unfocused", {raise=true})
      return c
    end
  end
  log("sigcont_by_prop: no client matched")
end

local onfocus = function(c)
  if not c.pid then
    return
  end

  if sigstop_timers[c.pid] then
      sigstop_timers[c.pid]:stop()
      sigstop_timers[c.pid] = nil
  end

  if sigstopped_pids[c.pid] then
    log("onfocus: "..c.pid)

    local prev_coords = mouse.coords()

    timer.start_new(stop_unfocused.config.delayed_focus_timeout, function()
      if not c.valid or client.focus ~= c then
        return false
      end

      if not sigstopped_pids[c.pid] then
        -- Continued already, e.g. request::activate.
        return
      end

      local coords = mouse.coords()
      if prev_coords.x == coords.x and prev_coords.y == coords.y then
        log("onfocus: cb")
        stop_unfocused.sigcont(c)
        log("onfocus: cb done")
        return false
      end
      prev_coords = coords
      return true
    end)
  end
end

local onunfocus = function(c)
  -- bnote('unfocus: c.name: '..c.name..', c.pid: '..c.pid)
  if not c.pid then
    return
  end

  if sigstopped_pids[c.pid] then
    log(string.format('onunfocus: %d is stopped already', c.pid))
    return
  end
  if stop_unfocused.ignore_clients[c] then
    log(string.format('onunfocus: %d is ignored', c.pid))
    return
  end

  local props, callbacks = get_props_and_callbacks(c, stop_unfocused.config.rules)
  if not props then
    -- Skip any client without a matching rule.
    return
  end

  local stop_timeout = props.stop_timeout
  if stop_timeout == nil then
    stop_timeout = stop_unfocused.config.stop_timeout
  end
  if not stop_timeout then
    return
  end

  if sigstop_timers[c.pid] then
    sigstop_timers[c.pid]:stop()
  end
  log(string.format("onunfocus: %d: starting timer (%.2fs)", c.pid, stop_timeout))
  sigstop_timers[c.pid] = timer.start_new(stop_timeout, function()
    log(string.format("onunfocus: %d: timer cb", c.pid))
    -- TODO: check if not continued already!?
    if c.valid then
      if not sigstop_timers[c.pid] then
        log("onunfocus: timer has been stopped")
        return
      end

      if c ~= client.focus and (not client.focus or c.pid ~= client.focus.pid) then
        stop_unfocused.sigstop(c, callbacks)
      end
    end
    sigstop_timers[c.pid] = nil
    return false
  end)
end
client.connect_signal("focus", onfocus)
client.connect_signal("unfocus", onunfocus)

client.connect_signal("request::activate", function(c, context, hints)  --luacheck: no unused args
  -- TODO: client might be stopped, but not registered (only through bugs
  -- though) - might be worthwile to ensure it being continued always?!
  if sigstopped_pids[c.pid] then
    log("request::activate: sigcont")
    stop_unfocused.sigcont(c)
    log("request::activate: done")
  end
end)

awesome.connect_signal("startup", function()
  log('startup: calling onunfocus for all clients')
  local clients = client.get()
  for _,c in pairs(clients) do
    if client.focus ~= c then
      onunfocus(c)
    end
  end
end)

awesome.connect_signal("exit", function(restarting)
  local pids = gears.table.keys(sigstopped_pids)
  if #pids > 0 then
    local child_pids = {}
    for _,config in pairs(sigstopped_pids) do
      child_pids = gears.table.join(child_pids, config._child_pids)
    end
    log(string.format("exit (restarting=%s): sending SIGCONT to %d stopped clients: %s",
                      restarting, #pids, table.concat(pids, ',')))
    for _,pid in pairs(pids) do
      awesome.kill(pid, awesome.unix_signal['SIGCONT'])
    end
    log(string.format("exit (restarting=%s): sending SIGCONT to %d stopped child PIDs: %s",
                      restarting, #child_pids, table.concat(child_pids, ',')))
    for _,pid in pairs(child_pids) do
      awesome.kill(pid, awesome.unix_signal['SIGCONT'])
    end
    log("exit: done")
  end
end)

return stop_unfocused

-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=8:softtabstop=4:textwidth=80
