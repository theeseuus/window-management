-- An allowlist of genuine new-window APIs. Never synthesize a generic Cmd+N:
-- in an unsupported app that could replace a chat, document, tab, or session.
local factory = {}

local commands = {
  ["com.mitchellh.ghostty"] = [[
tell application id "com.mitchellh.ghostty"
  set config to new surface configuration
  new window with configuration config
end tell]],
  ["com.apple.finder"] = [[
tell application id "com.apple.finder"
  make new Finder window
end tell]],
  ["com.apple.Safari"] = [[
tell application id "com.apple.Safari"
  make new document with properties {URL:"about:blank"}
end tell]],
}

function factory.support(bundleID)
  if not commands[bundleID] then return false, "unsupported-application" end
  local ok, info = pcall(hs.application.infoForBundleID, bundleID)
  if not ok or type(info) ~= "table" then return false, "application-not-installed" end
  if bundleID == "com.mitchellh.ghostty" then
    local major, minor = tostring(info.CFBundleShortVersionString):match("^(%d+)%.(%d+)")
    if not major or (tonumber(major) < 1)
      or (tonumber(major) == 1 and tonumber(minor) < 3)
      or not info.OSAScriptingDefinition then
      return false, "ghostty-requires-applescript-1.3"
    end
  end
  return true
end

local function run(path, arguments, options, complete, script)
  local job = { finished = false }
  local task, timer
  local ticks = 0
  local function finish(success, reason)
    if job.finished then return end
    job.finished = true
    if timer then timer:stop(); timer = nil end
    if task then
      local runningOK, running = pcall(function() return task:isRunning() end)
      if runningOK and running then pcall(function() task:terminate() end) end
      task = nil
    end
    complete(success, reason)
  end
  function job:cancel() finish(false, "establish-cancelled") end

  local function permitted()
    local ok, allowed, reason = pcall(options.guard)
    if not ok or not allowed then
      finish(false, ok and (reason or "context-unavailable") or "context-unavailable")
      return false
    end
    return true
  end
  if not permitted() then return job end

  local madeOK, made = pcall(hs.task.new, path, function(code, stdout)
    if job.finished or not permitted() then return end
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
    if job.finished or not permitted() then return end
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

function factory.launch(bundleID, options, complete)
  return run("/usr/bin/open", { "-g", "-b", bundleID }, options, complete, false)
end

function factory.create(bundleID, options, complete)
  local command = commands[bundleID]
  if not command then
    local job = { finished = true, cancel = function() end }
    complete(false, "unsupported-application")
    return job
  end
  local script = "with timeout of 10 seconds\ntry\n" .. command
    .. '\nreturn "created"\non error message number errorNumber\n'
    .. 'return "ERROR:" & errorNumber\nend try\nend timeout'
  return run("/usr/bin/osascript", { "-e", script }, options, complete, true)
end

return factory
