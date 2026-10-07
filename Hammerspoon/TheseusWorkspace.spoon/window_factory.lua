-- An allowlist of genuine new-window APIs. Never synthesize a generic Cmd+N:
-- in an unsupported app that could replace a chat, document, tab, or session.
local factory = {}

local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local adapters = dofile(sourcePath .. "app_adapters.lua")

function factory.support(bundleID)
  local adapter = adapters[bundleID]
  if not adapter then return false, "unsupported-application" end
  local ok, info = pcall(hs.application.infoForBundleID, bundleID)
  if not ok or type(info) ~= "table" then return false, "application-not-installed" end
  if adapter.checkInstalled then return adapter.checkInstalled(info) end
  return true
end

local function permitted(options)
  local ok, allowed, reason = pcall(options.guard)
  return ok and allowed, ok and (reason or "context-unavailable") or "context-unavailable"
end

local function run(path, arguments, options, complete, script)
  local job = { finished = false }
  local task, timer
  local ticks = 0
  local function finish(success, reason, windowID)
    if job.finished then return end
    job.finished = true
    if timer then timer:stop(); timer = nil end
    if task then
      local runningOK, running = pcall(function() return task:isRunning() end)
      if runningOK and running then pcall(function() task:terminate() end) end
      task = nil
    end
    complete(success, reason, windowID)
  end
  function job:cancel() finish(false, "establish-cancelled") end

  local function checkContext()
    local allowed, reason = permitted(options)
    if not allowed then
      finish(false, reason)
      return false
    end
    return true
  end
  if not checkContext() then return job end

  local madeOK, made = pcall(hs.task.new, path, function(code, stdout)
    if job.finished or not checkContext() then return end
    if code ~= 0 then
      -- Do not retain raw AppleScript stderr or application-returned text.
      finish(false, "window-command-failed")
    elseif script then
      local errorCode = tostring(stdout):match("ERROR:(%-?%d+)")
      if errorCode then
        local reasons = {
          ["-1743"] = "automation-not-authorized",
          ["-1712"] = "window-command-timed-out",
          ["-1708"] = "new-window-command-unavailable",
        }
        finish(false, reasons[errorCode] or "window-command-failed")
      elseif script == "window-id" then
        local windowID = tonumber(tostring(stdout):match("^created:(%d+)%s*$"))
        if windowID and windowID > 0 and windowID <= 4294967295 then
          finish(true, nil, windowID)
        else
          finish(false, "unexpected-window-command-result")
        end
      elseif tostring(stdout):match("^created%s*$") then
        finish(true)
      else
        finish(false, "unexpected-window-command-result")
      end
    else
      finish(true)
    end
  end, arguments)
  if not madeOK or not made then
    finish(false, "could-not-start-window-command")
    return job
  end
  task = made
  local startOK, started = pcall(function() return task:start() end)
  if not startOK or not started then
    finish(false, "could-not-start-window-command")
    return job
  end

  local function check()
    if job.finished or not checkContext() then return end
    ticks = ticks + 1
    if ticks >= 60 then
      finish(false, "window-command-timed-out")
      return
    end
    local ok, scheduled = pcall(hs.timer.doAfter, 0.25, check)
    if not ok or not scheduled then
      finish(false, "could-not-schedule-window-check")
    else
      timer = scheduled
    end
  end
  if not job.finished then check() end
  return job
end

local function rejected(reason, complete)
  local job = { finished = true, cancel = function() end }
  complete(false, reason)
  return job
end

local function selectNewWindow(bundleID, menu, options, complete)
  local job = { finished = false }
  local timer
  local function finish(success, reason)
    if job.finished then return end
    job.finished = true
    if timer then timer:stop(); timer = nil end
    complete(success, reason)
  end
  function job:cancel() finish(false, "establish-cancelled") end
  local function checkContext()
    local allowed, reason = permitted(options)
    if not allowed then finish(false, reason); return false end
    return true
  end
  if not checkContext() then return job end

  local scheduledOK, scheduled = pcall(hs.timer.doAfter, 0, function()
    timer = nil
    if job.finished or not checkContext() then return end
    local appOK, app = pcall(hs.application.get, bundleID)
    if not appOK or not app then finish(false, "application-not-running"); return end
    local identityOK, identity = pcall(function() return app:bundleID() end)
    if not identityOK or identity ~= bundleID then
      finish(false, "application-identity-mismatch"); return
    end
    local menuOK, item = pcall(function() return app:findMenuItem(menu) end)
    if not menuOK or type(item) ~= "table" then
      finish(false, "new-window-command-unavailable"); return
    end
    if not item.enabled then finish(false, "new-window-menu-disabled"); return end
    if not checkContext() then return end
    -- No activation, key synthesis, New Chat, or fallback menu selection.
    local selectOK, selected = pcall(function() return app:selectMenuItem(menu) end)
    if not checkContext() then return end
    if selectOK and selected == true then finish(true)
    else finish(false, "window-command-failed") end
  end)
  if not scheduledOK or not scheduled then finish(false, "could-not-schedule-window-check")
  elseif not job.finished then timer = scheduled end
  return job
end

function factory.launch(bundleID, options, complete)
  if not adapters[bundleID] then return rejected("unsupported-application", complete) end
  return run("/usr/bin/open", { "-g", "-b", bundleID }, options, complete, false)
end

local function wrappedScript(script)
  return "with timeout of 10 seconds\ntry\n" .. script
    .. '\nreturn "created"\non error message number errorNumber\n'
    .. 'return "ERROR:" & errorNumber\nend try\nend timeout'
end

function factory.create(bundleID, options, complete)
  local adapter = adapters[bundleID]
  if not adapter then return rejected("unsupported-application", complete) end
  if adapter.kind == "menu" then return selectNewWindow(bundleID, adapter.menu, options, complete) end
  if adapter.kind == "launch-only" then return rejected(adapter.reason, complete) end
  return run("/usr/bin/osascript", { "-e", wrappedScript(adapter.script) },
    options, complete, adapter.resultKind or true)
end

function factory.navigateCreated(bundleID, windowID, options, complete)
  local adapter = adapters[bundleID]
  if not adapter or not adapter.navigationScript then
    return rejected("new-window-navigation-unavailable", complete)
  end
  -- The only dynamic script value is a bounded native ID from the creation
  -- receipt, checked against the independently discovered window. No recipe
  -- name, URL, title or arbitrary text reaches this transport.
  if type(windowID) ~= "number" or windowID < 1 or windowID > 4294967295
    or windowID % 1 ~= 0 then
    return rejected("new-window-identity-mismatch", complete)
  end
  return run("/usr/bin/osascript", { "-e", wrappedScript(adapter.navigationScript(windowID)) },
    options, complete, true)
end

return factory
