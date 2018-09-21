--- Manage sending SIGSTOP signals to special clients when they are unfocused.
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

local gears = require('gears')
local timer = require('gears.timer')

--- Print a log message.
-- @tparam string message The message to print.
local function log(...)
  local args = {...}
  local msg
  if #args == 1 then
    msg = args[1]
  else
    local sliced = gears.table.iterate(args, function (_) return true end, 2)
    msg = gears.debug.dump_return(sliced(), args[1])
  end
  io.stderr:write(os.date("%Y-%m-%d %T stop_unfocused: ") .. tostring(msg) .. "\n")
end

local awful = require('awful')
if not awful.rules.get_props_and_callbacks then
function awful.rules.get_props_and_callbacks(c, _rules)
    local matching_rules = awful.rules.matching_rules(c, _rules)
    if #matching_rules == 0 then
        return
    end
    local props = {}
    local callbacks = {}
    for _, entry in ipairs(matching_rules) do
        if entry.properties then
            for property, value in pairs(entry.properties) do
                props[property] = value
            end
        end
        if entry.callback then
            table.insert(callbacks, entry.callback)
        end
    end
    return props, callbacks
end
end

local stop_unfocused = {}

-- TODO: do not stop "Sending Message" client window with Thunderbird.
--       class: Thunderbird, name: Sending Message, instance: Dialog
stop_unfocused.config = {
  rules = {
    {rule = {class = 'qutebrowser'}},
    {rule = {class = 'Firefox'}},
    {rule = {class = 'Thunderbird'}},
  },
  stop_timeout = 30,
  -- stop_callback = stop_unfocused.sigstop,
  -- cont_callback = stop_unfocused.sigcont,
}

stop_unfocused.ignore_clients = {}

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

-- A table of stopped clients as key, and callbacks as values.
local sigstopped_clients = {}

local stopping_cbs = {}

--- Call the next callback from `queue` for client `c`.
-- The callback is called with args `c`, `stop` and `next_cb`, and needs to call
-- `next_cb` (without any args).
local function call_next_callback(c, stop, queue)
  local k, cb = next(queue)
  log('== call_next_callback: (' .. (stop and 'stop' or 'cont') .. ' ==', k, cb, stop)
  if stop and not sigstopped_clients[c] then
    log('Aborting stop callbacks for continued client.')
    return
  end
  if cb then
    local function next_cb()
      log('== next_cb ==', c.valid and c or 'invalid c', stop, queue, #queue)
      -- TODO: pass through c.pid directly for when c becomes invalid?!
      if stopping_cbs[c.pid] then
        log('Removing finished stop cb with PID '..tostring(stopping_cbs[c.pid]))
        awesome.kill(stopping_cbs[c.pid], awesome.unix_signal['SIGTERM'])
        stopping_cbs[c.pid] = nil
      end
      call_next_callback(c, stop, queue)
    end
    queue[k] = nil
    log('Calling callback '..tostring(cb), stop, c, next_cb)
    local maybe_pid = gears.protected_call(cb, c, stop, next_cb)
    log('Return from callback '..tostring(cb)..': ' .. tostring(maybe_pid))
    if stop and type(maybe_pid) == 'number' then
      log('Got PID, adding to stopping_cbs: ' .. tostring(maybe_pid) .. '.')
      stopping_cbs[c.pid] = maybe_pid
    end
    return
  end
  log('callbacks done')
end

function stop_unfocused.sigstop(c, callbacks)
  if c.pid then
    -- Use xsel to keep the primary selection, otherwise it will block until the
    -- process gets continued when trying to paste it (middle-mouse).
    -- XXX: sometimes qutebrowser is not continued (used a
    -- callback, which might need to get chained?!)
    log('stopping ' .. c.pid)
    -- NOTE: use awful.spawn instead of awesome.kill, so xsel gets executed.
    -- awful.spawn({'sh', '-c', 'xsel --keep --primary && sleep 1 && kill -STOP ' .. tostring(c.pid) .. ' && echo stopped ' .. tostring(c.pid)})
    -- awful.spawn({'sh', '-c', 'echo copying selection; copyq "copySelection(selection())" && sleep 1 && kill -STOP ' .. tostring(c.pid) .. ' && echo stopped ' .. tostring(c.pid)})

    -- Add any other clients with the same pid.
    for _,v in ipairs(client.get()) do
      if v ~= c and v.pid == c.pid then
        sigstopped_clients[v] = {}
      end
    end

    callbacks = callbacks or {}
    sigstopped_clients[c] = callbacks
    log('marking stopped: '..c.pid..' ('..tostring(#callbacks)..' custom callbacks)')

    local function main_stop(_, _, done_cb)
      -- XXX: xclip might hang?!  (needs to be killed then)
      -- 2018-06-28 15:03:19 stop_unfocused: stderr: Error: target STRING not available
      -- Connected to X server.
      -- Using selection: XA_CLIPBOARD
      -- Connected to X server.
      -- Using selection: XA_PRIMARY
      -- Using UTF8_STRING.
      -- Using UTF8_STRING.
      -- Waiting for selection requests, Control-C to quit
      --   Waiting for selection request number 1
      -- Waiting for selection requests, Control-C to quit
      --   Waiting for selection request number 1
      --   Waiting for selection request number 2
      --   Waiting for selection request number 2
      --   Waiting for selection request number 3
      --   Waiting for selection request number 4
      --   Waiting for selection request number 5
      --
      -- 2018-06-28 15:03:19 stop_unfocused: exit: 0
      local pid_or_error = stop_unfocused.spawn_with_cb_on_exit({
        'sh', '-c',
        -- 'echo "$(date) copying"; '
        ''
        -- .. 'xclip -o -selection clipboard | nohup xclip -verbose -selection clipboard >/dev/null & '
        -- .. 'xclip -o -selection primary | nohup xclip -verbose -selection primary >/dev/null & '
        -- .. 'awesome-client \'bnote("copying")\'; '
        .. '(copyq "copySelection(selection())" &&'
        .. 'copyq "copy(clipboard())" &&'
        .. 'sleep 1); '
        -- .. string.format('awesome-client \'bnote("stopping %d (%s)")\'; ', c.pid, c.name)
        .. 'echo "$(date) stopping"; kill -STOP ' .. tostring(c.pid) .. ';'
        -- .. 'awesome-client "bnote(\'state: '..tostring(c.pid)..': $(ps -p '..tostring(c.pid)..' -o state=)\')"; '
        -- .. 'echo "$(date) stopped ' .. tostring(c.pid) .. '"'
        },
        done_cb)
      if type(pid_or_error) == 'string' then
        gears.debug.print_error('Failed to run main_stop: ' .. pid_or_error)
      else
        return pid_or_error
      end
    end
    call_next_callback(c, true, gears.table.merge({main_stop}, callbacks) or {})

    -- awful.spawn({'sh', '-c', 'kill -STOP ' .. tostring(c.pid) .. ' && echo stopped ' .. tostring(c.pid)})
    -- awful.spawn({})
    -- awesome.kill(c.pid, 19)

    -- NOTE: stopping happens in main cb.
    -- log("sigstop: kill -STOP " .. tostring(c.pid))
    -- awesome.kill(c.pid, awesome.unix_signal['SIGSTOP'])
  end
end

function stop_unfocused.sigcont(c)
  if c.pid then
    local callbacks = sigstopped_clients[c]
    if not callbacks then
      return
    end
    -- bnote('-CONT ' .. c.pid)

    callbacks = gears.table.clone(sigstopped_clients[c])

    log('marking continued: '..c.pid)
    sigstopped_clients[c] = nil
    -- Remove any other clients with the same pid.
    for k,_ in pairs(sigstopped_clients) do
      if not k.valid or (k ~= c and k.pid == c.pid) then
        sigstopped_clients[k] = nil
      end
    end

    if stopping_cbs[c.pid] then
      log('Killing stop cb with PID '..tostring(stopping_cbs[c.pid]))
      awesome.kill(stopping_cbs[c.pid], awesome.unix_signal['SIGTERM'])
      stopping_cbs[c.pid] = nil
    end

    local function main_cont(_, _, next_cb)
      -- awful.spawn({'pkill', '-CONT', '-g', tostring(c.pid)})
      log("main_cont: kill -CONT " .. tostring(c.pid))
      awesome.kill(c.pid, awesome.unix_signal['SIGCONT'])
      next_cb()
    end
    callbacks = gears.table.merge({main_cont}, callbacks)
    log(tostring(#callbacks) .. ' cont callbacks')

    call_next_callback(c, false, callbacks)
  end
end

local function delayed_cont(c, mouse_coords)
  if client.focus == c then
    local coords = mouse.coords()
    if mouse_coords.x == coords.x and mouse_coords.y == coords.y then
      -- bnote('delayed_cont')
      stop_unfocused.sigcont(c)
    else
      timer.start_new(0.05, function()
        timer.delayed_call(function() delayed_cont(c, coords) end)
      end)
    end
  end
end

local onfocus = function(c)
  if sigstop_timers[c.pid] then
      sigstop_timers[c.pid]:stop()
      sigstop_timers[c.pid] = nil
  end

  if c.pid then
    if sigstopped_clients[c] then
      local coords = mouse.coords()
      timer.delayed_call(function() delayed_cont(c, coords) end)
    end
  end
end
local sigstop_unfocus = function(c)
  -- bnote('unfocus: c.name: '..c.name..', c.pid: '..c.pid)
  -- bnote(sigstopped_clients[c])

  if c.pid and not sigstopped_clients[c] and not c.ontop and not stop_unfocused.ignore_clients[c] then
    -- local rules = awful.rules.matching_rules(c, stop_unfocused.config.rules)
    local props, callbacks = awful.rules.get_props_and_callbacks(c, stop_unfocused.config.rules)

    if props then
      props = gears.table.join({
          stop_timeout = stop_unfocused.config.stop_timeout,
        }, props)
      -- bnote(c.name)
      -- bnote(gears.debug.dump_return(props, 'props'))
      -- bnote(gears.debug.dump_return(callbacks, 'callbacks'))
      -- local timeout = stop_unfocused.config.stop_timeout
      -- local stop_callback = stop_unfocused.config.stop_callback or stop_unfocused.sigstop

      -- for _, entry in pairs(rules) do
      --   if entry.timeout then
      --     timeout = entry.timeout
      --   end
      --   if entry.stop_callback then
      --     stop_callback = entry.stop_callback
      --   end
      -- end
      if props.stop_timeout then
        local pid = tostring(c.pid)
        if sigstop_timers[pid] then
          sigstop_timers[pid]:stop()
        end
        sigstop_timers[pid] = timer.start_new(props.stop_timeout, function()
          if c.valid and c ~= client.focus and c.pid ~= client.focus.pid then
            stop_unfocused.sigstop(c, callbacks)
          end
          sigstop_timers[pid] = nil
          return false
        end)
      end
    end
  end
end
client.connect_signal("focus", onfocus)
client.connect_signal("unfocus", sigstop_unfocus)

client.connect_signal("request::activate", function(c, context, hints)  --luacheck: no unused args
  if sigstopped_clients[c] then
    -- bnote('request::activate: cont')
    stop_unfocused.sigcont(c)
  end
end)

-- Restart any stopped clients when exiting/restarting.
awesome.connect_signal("exit", function()
  for c, callbacks in pairs(sigstopped_clients) do
    stop_unfocused.sigcont(c, callbacks)
  end
end)

return stop_unfocused

-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=8:softtabstop=4:textwidth=80
