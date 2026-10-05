local path = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = path:match("^(.*)/tests/$")
local assertions = 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local previousHs = hs
local info, tasks, timers, allowed, failNew, failStart, failSchedule
local result, calls
local app, menuItem, menuCalls, menuError, menuSelected, identity
local function reset()
  info = { CFBundleShortVersionString = "1.3.1", OSAScriptingDefinition = "Ghostty.sdef" }
  tasks, timers, allowed = {}, {}, true
  failNew, failStart, failSchedule, result, calls = false, false, false, nil, 0
  menuItem, menuCalls, menuError, menuSelected, identity = { enabled = true }, {}, nil, true, nil
  app = {
    bundleID = function() return identity or "com.openai.codex" end,
    findMenuItem = function(_, menu)
      equal(table.concat(menu, "/"), "File/New Window", "exact genuine menu path")
      if menuError == "lookup" then error("private application text") end
      return menuItem
    end,
    selectMenuItem = function(_, menu)
      table.insert(menuCalls, table.concat(menu, "/"))
      if menuError == "selection" then error("private application text") end
      if menuError == "space" then allowed = false end
      return menuSelected
    end,
  }
end
local function complete(ok, reason) calls = calls + 1; result = { ok = ok, reason = reason } end
local options = { guard = function() return allowed, "active-space-changed" end }
hs = {
  application = {
    infoForBundleID = function() return info end,
    get = function() return app end,
  },
  task = { new = function(executable, callback, arguments)
    if failNew then return nil end
    local task = { executable = executable, callback = callback, arguments = arguments }
    function task:start() self.running = not failStart; return self.running and self or false end
    function task:isRunning() return self.running end
    function task:terminate() self.terminated = true; self.running = false end
    function task:finish(code, stdout, stderr)
      self.running = false
      self.callback(code, stdout or "", stderr or "")
    end
    table.insert(tasks, task)
    return task
  end },
  timer = { doAfter = function(_, callback)
    if failSchedule then return nil end
    local timer = { callback = callback }
    function timer:stop() self.stopped = true end
    table.insert(timers, timer)
    return timer
  end },
}
local factory = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/window_factory.lua")
local function drain()
  local ticks = 0
  while #timers > 0 do
    ticks = ticks + 1
    assert(ticks < 65, "task waits must be bounded")
    local timer = table.remove(timers, 1)
    if not timer.stopped then timer.callback() end
  end
end

reset()
equal(factory.support("com.apple.finder"), true, "Finder capability")
equal(factory.support("com.apple.Safari"), true, "Safari capability")
equal(factory.support("com.mitchellh.ghostty"), true, "Ghostty scripting capability")
for _, bundle in ipairs({ "com.google.Chrome", "com.barebones.bbedit", "com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop" }) do
  equal(factory.support(bundle), true, "allowlisted Establish lifecycle for " .. bundle)
end
local ok, err = factory.support("com.example.Chat")
equal(ok, false, "do not infer a chat app's new-window behavior")
equal(err, "unsupported-application", "unsupported reason")
for _, version in ipairs({ "1.2.3", "0.9.0", "unavailable" }) do
  info.CFBundleShortVersionString = version
  ok, err = factory.support("com.mitchellh.ghostty")
  equal(ok, false, "reject unsupported Ghostty " .. version)
  equal(err, "ghostty-requires-applescript-1.3", "version-specific reason")
end
info.CFBundleShortVersionString, info.OSAScriptingDefinition = "1.3.1", nil
equal(factory.support("com.mitchellh.ghostty"), false, "require installed scripting dictionary")
info = nil
ok, err = factory.support("com.apple.Safari")
equal(ok, false, "missing installed app")
equal(err, "application-not-installed", "installation-specific reason")

reset()
local job = factory.create("com.mitchellh.ghostty", options, complete)
equal(job.finished, false, "creation is asynchronous")
equal(tasks[1].executable, "/usr/bin/osascript", "native scripting executable")
equal(tasks[1].arguments[1], "-e", "script is an argument, not shell interpolation")
local script = tasks[1].arguments[2]
equal(script:find("new window with configuration config", 1, true) ~= nil, true, "genuine Ghostty window command")
equal(script:find("activate", 1, true), nil, "do not activate an old project window")
equal(script:find("input text", 1, true), nil, "do not run terminal commands")
tasks[1]:finish(0, "created\n")
equal(job.finished, true, "script completion finishes task")
equal(result.ok, true, "script success")
drain()
equal(calls, 1, "complete exactly once")

for _, case in ipairs({
  { "com.apple.finder", "make new Finder window" },
  { "com.apple.Safari", 'make new document with properties {URL:"about:blank"}' },
  { "com.barebones.bbedit", "make new text window" },
  { "com.google.Chrome", "set createdWindow to make new window" },
}) do
  reset()
  factory.create(case[1], options, complete)
  equal(tasks[1].arguments[2]:find(case[2], 1, true) ~= nil, true, "fixed window API for " .. case[1])
  if case[1] == "com.google.Chrome" then
    equal(tasks[1].arguments[2]:find('set URL of active tab of createdWindow to "about:blank"', 1, true) ~= nil, true, "blank only the newly created Chrome window")
    equal(tasks[1].arguments[2]:find("window 1", 1, true), nil, "never navigate the existing front browser window")
  end
  tasks[1]:finish(0, "created")
end
for _, case in ipairs({
  { "ERROR:-1743", "automation-not-authorized" },
  { "ERROR:-1712", "window-command-timed-out" },
  { "ERROR:-1708", "new-window-command-unavailable" },
  { "ERROR:-9999", "window-command-failed" },
  { "arbitrary application text", "unexpected-window-command-result" },
}) do
  reset()
  job = factory.create("com.apple.Safari", options, complete)
  tasks[1]:finish(0, case[1], "private diagnostic must not be retained")
  equal(result.ok, false, "not a successful creation")
  equal(result.reason, case[2], "safe categorical error")
end
reset()
factory.create("com.apple.finder", options, complete)
tasks[1]:finish(1, "", "application metadata must not leak")
equal(result.reason, "window-command-failed", "discard raw process stderr")

reset()
factory.launch("com.apple.Safari", options, complete)
equal(tasks[1].executable, "/usr/bin/open", "background app launch")
equal(table.concat(tasks[1].arguments, " "), "-g -b com.apple.Safari", "launch without focusing an old window")
tasks[1]:finish(0)
equal(result.ok, true, "launch task result is separate from window verification")

reset()
allowed = false
job = factory.create("com.apple.finder", options, complete)
equal(#tasks, 0, "check destination before starting command")
equal(result.reason, "active-space-changed", "pre-launch guard")
reset()
job = factory.create("com.apple.finder", options, complete)
allowed = false
drain()
equal(tasks[1].terminated, true, "stop script when destination changes")
equal(result.reason, "active-space-changed", "periodic guard")
tasks[1]:finish(0, "created")
equal(calls, 1, "ignore late success after guard cancellation")

reset()
job = factory.create("com.apple.finder", options, complete)
job:cancel()
equal(tasks[1].terminated, true, "cancel only the child command, not the application")
equal(result.reason, "establish-cancelled", "explicit cancellation reason")
tasks[1]:finish(0, "created")
drain()
equal(calls, 1, "cancelled callbacks cannot create duplicate results")
reset()
factory.create("com.apple.finder", options, complete)
drain()
equal(result.reason, "window-command-timed-out", "bounded hung task")
equal(tasks[1].terminated, true, "terminate a timed-out child")
for _, failure in ipairs({ "allocation", "start", "timer" }) do
  reset()
  failNew, failStart, failSchedule = failure == "allocation", failure == "start", failure == "timer"
  factory.create("com.apple.finder", options, complete)
  equal(result.ok, false, "fail safely on " .. failure)
  equal(calls, 1, "report " .. failure .. " once")
end
reset()
factory.create("com.example.Chat", options, complete)
equal(#tasks, 0, "unsupported apps never receive a generic shortcut")
equal(result.reason, "unsupported-application", "unsupported create is safe")

for _, bundle in ipairs({ "com.openai.codex", "com.openai.chat" }) do
  reset()
  identity = bundle
  job = factory.create(bundle, options, complete)
  equal(job.finished, false, "menu dispatch is asynchronous")
  equal(#menuCalls, 0, "no premature menu selection")
  drain()
  equal(menuCalls[1], "File/New Window", "dispatch only an independent-window command")
  equal(#tasks, 0, "menu creation does not run AppleScript or synthesize keys")
  equal(result.ok, true, "menu selection accepted; orchestrator still verifies the new window")
  equal(result.reason, nil, "successful menu has no failure reason")
  equal(calls, 1, "menu completion exactly once")
end
for _, case in ipairs({
  { "missing", "new-window-command-unavailable" },
  { "disabled", "new-window-menu-disabled" },
  { "lookup", "new-window-command-unavailable" },
  { "selection", "window-command-failed" },
  { "not-running", "application-not-running" },
  { "identity", "application-identity-mismatch" },
  { "space", "active-space-changed" },
  { "declined", "window-command-failed" },
}) do
  reset()
  if case[1] == "missing" then menuItem = nil
  elseif case[1] == "disabled" then menuItem.enabled = false
  elseif case[1] == "not-running" then app = nil
  elseif case[1] == "identity" then identity = "com.example.Other"
  elseif case[1] == "declined" then menuSelected = nil
  else menuError = case[1] end
  factory.create("com.openai.codex", options, complete)
  drain()
  equal(result.ok, false, "fail closed on menu " .. case[1])
  equal(result.reason, case[2], "safe menu failure category")
  equal(calls, 1, "no repeated menu callback")
  equal(#menuCalls <= 1, true, "never retry or fall back to New Chat")
end
reset()
job = factory.create("com.openai.codex", options, complete)
job:cancel()
drain()
equal(#menuCalls, 0, "cancel before menu selection")
equal(calls, 1, "menu cancellation completes once")
reset()
factory.create("com.openai.codex", options, complete)
allowed = false
drain()
equal(#menuCalls, 0, "guard queued menu against Space change")
equal(result.reason, "active-space-changed", "queued guard category")
reset()
failSchedule = true
factory.create("com.openai.codex", options, complete)
equal(result.reason, "could-not-schedule-window-check", "menu scheduling failure")
equal(#menuCalls, 0, "failed menu scheduling has no side effect")
reset()
factory.create("com.anthropic.claudefordesktop", options, complete)
equal(result.reason, "claude-new-window-unavailable", "Claude launch-only limitation is explicit")
equal(#tasks, 0, "Claude never gets a guessed script")
equal(#menuCalls, 0, "Claude never gets New Chat as a window fallback")
factory.launch("com.anthropic.claudefordesktop", options, complete)
equal(table.concat(tasks[1].arguments, " "), "-g -b com.anthropic.claudefordesktop", "Claude may launch to supply a default main window")
reset()
factory.launch("com.example.Unrequested", options, complete)
equal(#tasks, 0, "direct launch remains allowlisted")
equal(result.reason, "unsupported-application", "unlisted launch rejected")

hs = previousHs
print(string.format("window_factory: %d assertions passed", assertions))
