local path = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = path:match("^(.*)/tests/$")
local assertions = 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local previousHs = hs
local info, tasks, timers, allowed, failNew, failStart, failSchedule
local result, calls, lookupCalls
local app, menuItem, menuCalls, menuError, menuSelected, identity, expectedMenu
local function reset()
  info = { CFBundleShortVersionString = "1.3.1", OSAScriptingDefinition = "Ghostty.sdef" }
  tasks, timers, allowed = {}, {}, true
  failNew, failStart, failSchedule, result, calls = false, false, false, nil, 0
  menuItem, menuCalls, menuError, menuSelected, identity = { enabled = true }, {}, nil, true, nil
  expectedMenu, lookupCalls = "File/New Window", 0
  app = {
    bundleID = function() return identity or "com.openai.codex" end,
    findMenuItem = function(_, menu)
      equal(table.concat(menu, "/"), expectedMenu, "exact genuine menu path")
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
    get = function() error("menu dispatch must not use a generic application search") end,
    applicationsForBundleID = function(bundleID)
      lookupCalls = lookupCalls + 1
      return app and { app } or {}
    end,
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
  timer = { doAfter = function(delay, callback)
    if failSchedule then return nil end
    local timer = { callback = callback, delay = delay }
    function timer:stop() self.stopped = true end
    table.insert(timers, timer)
    return timer
  end },
}
local function ax(attributes)
  return { attributeValue = function(_, key) return attributes[key] end }
end
local safariRoot = ax({ AXMenuBar = ax({ AXChildren = {
  ax({ AXTitle = "File", AXChildren = { ax({ AXChildren = {
    ax({ AXTitle = "New Personal Window", AXIdentifier = "NewPersonalWindow?isDefaultProfile=true" }),
  } }) } }),
} }) })
hs.axuielement = { applicationElement = function() return safariRoot end }
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
equal(factory.placementPolicy("com.superlogical.rex"), "position-only-when-sized", "exact Rex placement policy")
equal(factory.placementPolicy("com.mitchellh.ghostty"), nil, "Ghostty retains ordinary placement")
equal(factory.placementPolicy("com.apple.Safari"), nil, "Safari retains ordinary placement")
equal(factory.placementPolicy("com.example.Unknown"), nil, "unknown app has no placement policy")
equal(factory.support("com.apple.finder"), true, "Finder capability")
equal(factory.support("com.apple.Safari"), true, "Safari capability")
equal(factory.support("com.mitchellh.ghostty"), true, "Ghostty scripting capability")
for _, bundle in ipairs({ "com.google.Chrome", "com.barebones.bbedit", "com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop" }) do
  equal(factory.support(bundle), true, "allowlisted Establish lifecycle for " .. bundle)
end
local newApps = {
  "com.microsoft.Excel", "com.microsoft.Word", "com.microsoft.Powerpoint",
  "com.apple.iWork.Keynote", "com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.mail",
}
for _, bundle in ipairs(newApps) do
  equal(factory.support(bundle), true, "new installed adapter for " .. bundle)
end
for _, bundle in ipairs({ "com.apple.iCal", "com.apple.Preview", "com.microsoft.PowerPoint" }) do
  local supported, reason = factory.support(bundle)
  equal(supported, false, "do not guess a missing adapter for " .. bundle)
  equal(reason, "unsupported-application", "explicit unsupported capability")
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
  { "com.barebones.bbedit", "make new text window" },
  { "com.google.Chrome", "set createdWindow to make new window" },
  { "com.microsoft.Excel", "make new workbook" },
  { "com.microsoft.Word", "make new document" },
  { "com.microsoft.Powerpoint", "make new presentation" },
  { "com.apple.iWork.Keynote", "make new document" },
  { "com.apple.iWork.Pages", "make new document" },
  { "com.apple.iWork.Numbers", "make new document" },
}) do
  reset()
  factory.create(case[1], options, complete)
  equal(#tasks, 1, "one command per missing slot")
  equal(tasks[1].executable, "/usr/bin/osascript", "shared guarded scripting transport")
  equal(tasks[1].arguments[2]:find('tell application id "' .. case[1] .. '"', 1, true) ~= nil, true, "exact application identity")
  equal(tasks[1].arguments[2]:find(case[2], 1, true) ~= nil, true, "fixed window API for " .. case[1])
  equal(tasks[1].arguments[2]:find("activate", 1, true), nil, "creation never activates an existing window")
  if case[1] == "com.google.Chrome" then
    equal(tasks[1].arguments[2]:find('set URL of active tab of createdWindow to "about:blank"', 1, true) ~= nil, true, "blank only the newly created Chrome window")
    equal(tasks[1].arguments[2]:find("window 1", 1, true), nil, "never navigate the existing front browser window")
  end
  tasks[1]:finish(0, "created")
  equal(result.ok, true, "successful native dispatch")
  equal(calls, 1, "complete native dispatch once")
end
for _, case in ipairs({
  { "ERROR:-1743", "automation-not-authorized" },
  { "ERROR:-1712", "window-command-timed-out" },
  { "ERROR:-1708", "new-window-command-unavailable" },
  { "ERROR:-9999", "window-command-failed" },
  { "arbitrary application text", "unexpected-window-command-result" },
}) do
  reset()
  job = factory.create("com.apple.finder", options, complete)
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
for _, bundle in ipairs(newApps) do
  reset()
  factory.launch(bundle, options, complete)
  equal(tasks[1].executable, "/usr/bin/open", "shared cold-launch transport")
  equal(table.concat(tasks[1].arguments, " "), "-g -b " .. bundle, "background launch of exact app")
  tasks[1]:finish(0)
  equal(result.ok, true, "launch command accepted; windows still need verification")
  reset()
  allowed = false
  factory.launch(bundle, options, complete)
  equal(#tasks, 0, "guard each new app before launch")
  equal(result.reason, "active-space-changed", "new app launch fails closed after Space change")
end

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

for _, bundle in ipairs({ "com.openai.codex", "com.openai.chat", "com.apple.mail", "com.superlogical.rex", "com.apple.Safari" }) do
  reset()
  identity = bundle
  expectedMenu = bundle == "com.apple.mail" and "File/New Viewer Window" or "File/New Window"
  if bundle == "com.apple.Safari" then expectedMenu = "File/New Personal Window" end
  job = factory.create(bundle, options, complete)
  equal(job.finished, false, "menu dispatch is asynchronous")
  equal(#menuCalls, 0, "no premature menu selection")
  drain()
  equal(menuCalls[1], expectedMenu, "dispatch only an independent-window command")
  equal(#tasks, 0, "menu creation does not run AppleScript or synthesize keys")
  equal(result.ok, true, "menu selection accepted; orchestrator still verifies the new window")
  equal(result.reason, nil, "successful menu has no failure reason")
  equal(calls, 1, "menu completion exactly once")
end
for _, failure in ipairs({ "missing", "disabled", "identity", "space", "cancel" }) do
  reset()
  identity, expectedMenu = "com.apple.mail", "File/New Viewer Window"
  if failure == "missing" then menuItem = nil
  elseif failure == "disabled" then menuItem.enabled = false
  elseif failure == "identity" then identity = "com.example.Other"
  elseif failure == "space" then allowed = false end
  job = factory.create("com.apple.mail", options, complete)
  if failure == "cancel" then job:cancel() end
  drain()
  equal(result.ok, false, "Mail fails safely on " .. failure)
  equal(#menuCalls, 0, "Mail cannot fall back to a new message")
  equal(#tasks, 0, "Mail cannot fall back to scripting")
  equal(calls, 1, "complete Mail failure once")
end
for _, bundle in ipairs({ "com.openai.codex", "com.superlogical.rex" }) do
  for _, case in ipairs({
    { "missing", "new-window-command-unavailable" },
    { "disabled", "new-window-menu-disabled" },
    { "lookup", "new-window-command-unavailable" },
    { "selection", "window-command-failed" },
    { "not-running", "application-not-found" },
    { "identity", "application-identity-mismatch" },
    { "space", "active-space-changed" },
    { "declined", "window-command-failed" },
  }) do
    reset()
    identity = bundle
    if case[1] == "missing" then menuItem = nil
    elseif case[1] == "disabled" then menuItem.enabled = false
    elseif case[1] == "not-running" then app = nil
    elseif case[1] == "identity" then identity = "com.example.Other"
    elseif case[1] == "declined" then menuSelected = nil
    else menuError = case[1] end
    factory.create(bundle, options, complete)
    drain()
    equal(result.ok, false, "fail closed on menu " .. case[1])
    equal(result.reason, case[2], "safe menu failure category")
    equal(calls, 1, "no repeated menu callback")
    equal(#menuCalls <= 1, true, "never retry or substitute a content command")
    equal(lookupCalls, case[1] == "not-running" and 3 or 1, "only absent application reads may retry")
  end
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


for _, failure in ipairs({ "missing", "exception", "space" }) do
  reset(); identity = "com.apple.Safari"
  local original = hs.axuielement.applicationElement
  hs.axuielement.applicationElement = function()
    if failure == "exception" then error("private application text") end
    if failure == "space" then allowed = false; return safariRoot end
    return nil
  end
  expectedMenu = "File/New Personal Window"
  factory.create("com.apple.Safari", options, complete); drain()
  equal(result.ok, false, "Safari resolver fails safely on " .. failure)
  equal(#menuCalls, 0, "no dispatch after failed resolution or changed Space")
  equal(#tasks, 0, "no Safari AppleScript fallback")
  equal(calls, 1, "resolver failure completes exactly once")
  hs.axuielement.applicationElement = original
end

-- Time native menu lookup and selection separately without retaining app text.
local diagnostics = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/establish_diagnostics.lua")
reset()
local now = 0
local trace = diagnostics.new(function() return now end)
local find, select = app.findMenuItem, app.selectMenuItem
app.findMenuItem = function(self, menu) now = now + 1.5; return find(self, menu) end
app.selectMenuItem = function(self, menu) now = now + 2; return select(self, menu) end
factory.create("com.openai.codex", { guard = options.guard, diagnostics = trace }, complete)
drain(); trace:finish()
equal(result.ok, true, "measured dispatch preserves success")
equal(trace.data.totals["menu-lookup:com.openai.codex"].durationSeconds, 1.5, "measure native lookup wall time")
equal(trace.data.totals["menu-select:com.openai.codex"].durationSeconds, 2, "measure native selection wall time")
equal(#menuCalls, 1, "timing does not dispatch an extra menu action")
reset(); menuError = "lookup"
trace = diagnostics.new(function() return now end)
factory.create("com.openai.codex", { guard = options.guard, diagnostics = trace }, complete)
drain(); trace:finish()
equal(result.reason, "new-window-command-unavailable", "measured lookup keeps categorical failure")
equal(trace.data.events[2].success, false, "failed menu lookup is visible in timeline")
equal(trace.data.events[2].reason, nil, "raw native exception text is not stored")

local originalLookup = hs.application.applicationsForBundleID
for _, mode in ipairs({ "exception", "absent", "invalid" }) do
  reset()
  hs.application.applicationsForBundleID = function(bundleID)
    equal(bundleID, "com.openai.codex", "lookup retains exact recipe identity")
    lookupCalls = lookupCalls + 1
    if mode == "exception" then error("private native error text") end
    if mode == "absent" then return {} end
    return nil
  end
  trace = diagnostics.new(function() return now end)
  factory.create("com.openai.codex", { guard = options.guard, diagnostics = trace }, complete)
  drain(); trace:finish()
  equal(result.reason, mode == "absent" and "application-not-found" or "application-lookup-failed", "distinguish failed lookup from an empty result")
  equal(lookupCalls, 3, "permanently unavailable app has a bounded read budget")
  equal(calls, 1, "exhausted lookup completes once")
  equal(#trace.data.events, 3, "record every read attempt without a menu event")
  for attempt, event in ipairs(trace.data.events) do
    equal(event.lookupSucceeded, mode ~= "exception", "preserve original lookup result flag")
    equal(event.found, false, "no application object on failed reads")
    equal(event.resultType, mode == "exception" and "string" or (mode == "absent" and "table" or "nil"), "retain type without native error contents")
    equal(event.attempt, attempt, "number application read attempts")
    equal(event.lookupMethod, "bundle-id", "report exact lookup method")
    equal(event.reason, nil, "raw native errors are not stored")
  end
  equal(#menuCalls, 0, "failed lookup never reaches menu selection")
end

-- Reproduce the observed running-app/empty-menu-lookup race. Reads may retry;
-- an enabled genuine menu command is still dispatched only once.
for _, mode in ipairs({ "absent", "exception", "invalid" }) do
  reset()
  hs.application.applicationsForBundleID = function(bundleID)
    equal(bundleID, "com.openai.codex", "retry never broadens the identity")
    lookupCalls = lookupCalls + 1
    if lookupCalls == 3 then return { app } end
    if mode == "exception" then error("private native error text") end
    if mode == "absent" then return {} end
    return nil
  end
  trace = diagnostics.new(function() return now end)
  factory.create("com.openai.codex", { guard = options.guard, diagnostics = trace }, complete)
  equal(timers[1].delay, 0, "first read has no added delay")
  table.remove(timers, 1).callback()
  equal(timers[1].delay, 0.1, "transient lookup yields briefly instead of blocking")
  equal(#menuCalls, 0, "empty first read cannot dispatch")
  drain(); trace:finish()
  equal(result.ok, true, "last permitted read recovers transient " .. mode)
  equal(lookupCalls, 3, "recovery stops at the successful read")
  equal(#menuCalls, 1, "recovery issues exactly one new-window command")
  equal(calls, 1, "recovery reports completion once")
  equal(#tasks, 0, "lookup recovery never launches a fallback process")
  equal(trace.data.events[3].found, true, "successful read is retained in the timeline")
end

reset()
hs.application.applicationsForBundleID = function()
  lookupCalls = lookupCalls + 1
  return { app, app }
end
factory.create("com.openai.codex", options, complete); drain()
equal(result.reason, "application-lookup-ambiguous", "multiple exact matches are not chosen arbitrarily")
equal(lookupCalls, 1, "ambiguous identity is not retried")
equal(#menuCalls, 0, "ambiguous identity cannot dispatch a menu")

for _, interruption in ipairs({ "cancel", "space", "scheduler" }) do
  reset()
  hs.application.applicationsForBundleID = function()
    lookupCalls = lookupCalls + 1
    if interruption == "scheduler" then failSchedule = true end
    return lookupCalls == 1 and {} or { app }
  end
  job = factory.create("com.openai.codex", options, complete)
  table.remove(timers, 1).callback()
  if interruption == "cancel" then job:cancel()
  elseif interruption == "space" then allowed = false end
  drain()
  equal(result.reason, interruption == "cancel" and "establish-cancelled"
    or (interruption == "space" and "active-space-changed" or "could-not-schedule-window-check"), "read wait respects " .. interruption)
  equal(lookupCalls, 1, "no further reads after interrupted wait")
  equal(#menuCalls, 0, "interrupted wait cannot create a window")
  equal(calls, 1, "interrupted lookup completes once")
end
hs.application.applicationsForBundleID = originalLookup

hs = previousHs
print(string.format("window_factory: %d assertions passed", assertions))
