local path = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = path:match("^(.*)/tests/$")
local establish = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/workspace_establish.lua")
local assertions = 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function recipe(bundles)
  local windows, ordinals = {}, {}
  for index, bundle in ipairs(bundles) do
    ordinals[bundle] = (ordinals[bundle] or 0) + 1
    table.insert(windows, {
      bundleID = bundle, appName = bundle, ordinal = ordinals[bundle],
      frame = { x = (index - 1) % 2 * 0.5, y = 0, w = 0.5, h = 0.5 },
    })
  end
  return { schemaVersion = 1, name = "Pilot", capturedAt = "2026-10-06T00:00:00Z", windows = windows }
end

local function environment()
  local env = {
    windows = {}, timers = {}, launches = {}, creates = {}, placements = {},
    running = {}, unsupported = {}, active = true, nextID = 100, completes = 0,
    collections = {}, events = {},
  }
  function env:add(bundle, properties)
    self.nextID = self.nextID + 1
    local window = {
      id = self.nextID, bundleID = bundle, appName = bundle, destination = true,
      frame = { x = 0.25, y = 0.25, w = 0.25, h = 0.25 },
    }
    for key, value in pairs(properties or {}) do window[key] = value end
    table.insert(self.windows, window)
    return window
  end
  local function enqueue(callback)
    local timer = { callback = callback }
    function timer:stop() self.stopped = true end
    table.insert(env.timers, timer)
    return timer
  end
  local function schedule(_, callback)
    if env.failTimer then return nil end
    return enqueue(callback)
  end
  local function child(callback)
    local job = { finished = false }
    function job:cancel() self.cancelled = true; self.finished = true end
    enqueue(function()
      if not job.finished then job.finished = true; callback() end
    end)
    return job
  end
  env.options = {
    scheduleAfter = schedule,
    guard = function() return env.active, "active-space-changed" end,
    collect = function(bundleID)
      table.insert(env.collections, bundleID or "all")
      if env.failCollect then return nil, "enumeration-failed" end
      if env.launchChecks then
        env.launchChecks = env.launchChecks + 1
        if env.launchChecks == env.launchAfterChecks then env.running[env.launchingBundle] = true end
        if env.launchChecks == env.launchWindowAfterChecks then env:add(env.launchingBundle) end
      end
      local candidates, seenIDs = {}, {}
      for _, window in ipairs(env.windows) do
        if not bundleID or window.bundleID == bundleID then
          seenIDs[window.id] = true
          if window.destination and not window.hidden then table.insert(candidates, window) end
        end
      end
      return candidates, nil, seenIDs
    end,
    support = function(bundle) return not env.unsupported[bundle], "unsupported-application" end,
    isRunning = function(bundle) return env.running[bundle] ~= false end,
    launch = function(bundle, callback)
      table.insert(env.launches, bundle)
      return child(function()
        if env.launchError then callback(false, env.launchError); return end
        env.launchingBundle, env.launchChecks = bundle, 0
        if not env.noLaunch and not env.launchAfterChecks then env.running[bundle] = true end
        if env.launchWindow and not env.launchWindowAfterChecks then env:add(bundle) end
        callback(true)
      end)
    end,
    create = function(bundle, callback)
      table.insert(env.events, "create:" .. bundle)
      table.insert(env.creates, bundle)
      return child(function()
        if env.createError then callback(false, env.createError); return end
        if env.changeSpace then env.active = false end
        if not env.noNewWindow then
          env:add(bundle, { destination = not env.wrongSpace })
          if env.ambiguous then env:add(bundle) end
        end
        callback(true)
      end)
    end,
    place = function(assignment, callback)
      table.insert(env.events, "place:" .. assignment.target.bundleID)
      table.insert(env.placements, assignment)
      return child(function()
        assignment.candidate.placed = true
        callback(not env.placeError, env.placeError, assignment.candidate.frame)
      end)
    end,
  }
  function env:start(layout)
    self.job = establish.start(layout, self.options, function(report)
      self.completes = self.completes + 1
      self.report = report
    end)
    return self.job.report
  end
  function env:drain()
    local steps = 0
    while #self.timers > 0 do
      steps = steps + 1
      assert(steps <= 150, "creation and placement waits must be bounded")
      local timer = table.remove(self.timers, 1)
      if not timer.stopped then timer.callback() end
    end
  end
  return env
end

local layout = recipe({ "Finder", "Finder", "Ghostty", "Safari" })
local env = environment()
local report = env:start(layout)
equal(report.finished, false, "establishment is asynchronous")
equal(report.applied, 0, "do not count a command as placement")
env:drain()
equal(report.finished, true, "finish verified establishment")
equal(env.completes, 1, "complete once")
equal(#env.creates, 4, "create exactly the missing window count")
equal(#env.launches, 0, "do not relaunch running apps")
equal(report.created, 4, "verified new windows")
equal(report.applied, 4, "verified placements")
equal(report.reused, 0, "first establish reused no windows")
equal(#report.missing, 0, "no missing slots")
equal(#report.failures, 0, "no placement failures")
equal(#report.creationFailures, 0, "no creation failures")
equal(report.pending, 0, "no pending checks")
equal(env.events[3], "place:Finder", "place the first app before creating the next app")
equal(env.events[4], "place:Finder", "match both same-app slots before placement")
equal(env.events[5], "create:Ghostty", "creation proceeds while previous placements verify")
local allScans = 0
for _, scope in ipairs(env.collections) do if scope == "all" then allScans = allScans + 1 end end
equal(allScans, 2, "scan the whole recipe only at start and final reconciliation")
report = env:start(layout)
env:drain()
equal(#env.creates, 4, "repeat establishment creates no duplicates")
equal(report.created, 0, "repeat has no new windows")
equal(report.reused, 4, "repeat reuses all four windows")
equal(report.applied, 4, "repeat re-establishes geometry")

-- Every new adapter follows the same lifecycle: count a cold-launch default
-- before requesting another window, then reuse both on repeat Establish.
for _, bundle in ipairs({
  "com.microsoft.Excel", "com.microsoft.Word", "com.microsoft.Powerpoint",
  "com.apple.iWork.Keynote", "com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.mail",
}) do
  env = environment()
  env.running[bundle], env.launchWindow = false, true
  local remote = env:add(bundle, { destination = false })
  local twoSlots = recipe({ bundle, bundle })
  report = env:start(twoSlots)
  env:drain()
  equal(#env.launches, 1, "launch closed app once: " .. bundle)
  equal(#env.creates, 1, "count startup window before filling second slot: " .. bundle)
  equal(report.created, 2, "verify default and explicit new windows: " .. bundle)
  equal(report.applied, 2, "place both new-app windows: " .. bundle)
  equal(#report.missing, 0, "both app slots established: " .. bundle)
  equal(remote.placed, nil, "protect other-Space app window: " .. bundle)
  report = env:start(twoSlots)
  env:drain()
  equal(#env.launches, 1, "no relaunch on repeat: " .. bundle)
  equal(#env.creates, 1, "no duplicate app window on repeat: " .. bundle)
  equal(report.reused, 2, "reuse both local windows: " .. bundle)
  equal(report.created, 0, "repeat creates nothing: " .. bundle)
end

env = environment()
local existing = env:add("Ghostty")
local extra = env:add("Ghostty", { frame = { x = 0.8, y = 0.8, w = 0.1, h = 0.1 } })
local otherSpace = env:add("Safari", { destination = false })
local hidden = env:add("Finder", { hidden = true })
report = env:start(recipe({ "Ghostty", "Safari", "Finder" }))
env:drain()
equal(#env.creates, 2, "reuse existing and create only missing")
equal(report.reused, 1, "reuse current-Space Ghostty")
equal(existing.placed, true, "place matching current-Space window")
equal(extra.placed, nil, "leave same-app extras untouched")
equal(otherSpace.placed, nil, "never borrow another project's window")
equal(hidden.placed, nil, "do not reuse a hidden window")
equal(#report.extras, 1, "report same-app extras")
equal(report.applied, 3, "all requested slots placed")

env = environment()
env.unsupported.Chat = true
env:add("Chat")
report = env:start(recipe({ "Chat", "Chat", "Ghostty" }))
env:drain()
equal(report.applied, 2, "reuse unsupported app's existing window")
equal(#env.creates, 1, "only supported missing slot gets a command")
equal(#report.missing, 1, "unsupported missing slot remains missing")
equal(report.creationFailures[1].appName, "Chat", "name unsupported app")
equal(report.creationFailures[1].reason, "unsupported-application", "explicit unsupported reason")

env = environment()
env.wrongSpace = true
report = env:start(recipe({ "Ghostty", "Ghostty" }))
env:drain()
equal(#env.creates, 1, "never retry a window that appeared elsewhere")
equal(report.created, 0, "wrong-Space creation is not verified")
equal(report.applied, 0, "wrong-Space window is never placed")
equal(#report.missing, 2, "both slots are still missing here")
equal(report.creationFailures[1].reason, "new-window-not-in-destination-space", "destination failure")
equal(env.windows[1].placed, nil, "do not move a wrong-Space window")

env = environment()
env.ambiguous = true
report = env:start(recipe({ "Ghostty" }))
env:drain()
equal(report.creationFailures[1].reason, "ambiguous-new-windows", "reject ambiguous creation identity")
equal(report.applied, 0, "do not place either ambiguous window")
equal(#report.extras, 2, "leave ambiguous windows as extras")

env = environment()
env.createError = "automation-not-authorized"
report = env:start(recipe({ "Ghostty", "Ghostty" }))
env:drain()
equal(#env.creates, 1, "do not retry denied automation")
equal(report.creationFailures[1].reason, "automation-not-authorized", "permission-specific failure")
equal(#report.missing, 2, "denied windows remain missing")

env = environment()
env.running.Ghostty, env.launchWindow = false, true
report = env:start(recipe({ "Ghostty", "Ghostty" }))
env:drain()
equal(#env.launches, 1, "launch missing app once")
equal(#env.creates, 1, "count launch-created default before requesting more")
equal(report.created, 2, "both launch and explicit creations verified")
equal(report.applied, 2, "place both new windows")
env = environment()
env.running.Ghostty = false
report = env:start(recipe({ "Ghostty" }))
env:drain()
equal(#env.creates, 1, "an app without a default window still gets one request")
equal(report.applied, 1, "place its genuine new window")
env = environment()
env.running.Ghostty, env.noLaunch = false, true
report = env:start(recipe({ "Ghostty" }))
env:drain()
equal(#env.creates, 0, "do not send new-window command to failed launch")
equal(report.creationFailures[1].reason, "application-did-not-launch", "bounded launch timeout")

env = environment()
env.running.Chrome, env.launchAfterChecks, env.launchWindowAfterChecks = false, 35, 40
report = env:start(recipe({ "Chrome", "Chrome" }))
env:drain()
equal(#env.launches, 1, "allow a cold process to become ready after five seconds")
equal(#env.creates, 1, "count the delayed startup window before filling another slot")
equal(report.created, 2, "both cold-start and explicit windows verified")
equal(report.applied, 2, "slow cold launch completes placement")
equal(#report.creationFailures, 0, "slow launch is not a premature failure")
env = environment()
env.running.Chrome, env.launchWindowAfterChecks = false, 35
report = env:start(recipe({ "Chrome" }))
env:drain()
equal(#env.creates, 0, "running process is not proof that its default window is ready")
equal(report.created, 1, "reuse the late default instead of creating a duplicate")
env = environment()
env.running.Claude, env.launchWindow = false, true
env.createError = "claude-new-window-unavailable"
report = env:start(recipe({ "Claude" }))
env:drain()
equal(#env.creates, 0, "launch-only app can establish its first main window")
equal(report.applied, 1, "place Claude's launch-created local main window")
equal(#report.creationFailures, 0, "no extra-window command needed")
report = env:start(recipe({ "Claude", "Claude" }))
env:drain()
equal(report.reused, 1, "retain and place an existing local Claude window")
equal(#report.missing, 1, "additional Claude slot remains explicitly missing")
equal(report.creationFailures[1].reason, "claude-new-window-unavailable", "launch-only limitation named")

env = environment()
env.changeSpace = true
report = env:start(recipe({ "Ghostty", "Safari" }))
env:drain()
equal(report.reason, "active-space-changed", "stop after destination changes")
equal(report.finished, true, "Space change finishes report")
equal(#env.creates, 1, "stop before the next app")
equal(#env.placements, 0, "never place after Space change")
env = environment()
report = env:start(recipe({ "Ghostty", "Safari" }))
env.job:cancel()
env:drain()
equal(report.cancelled, true, "stop marks cancellation")
equal(report.finished, true, "stop finishes operation")
equal(env.completes, 1, "stop completes exactly once")
equal(#env.windows, 0, "stop cancels pending new-window child")
equal(#env.placements, 0, "stop performs no late placements")
env = environment()
env:add("Ghostty")
env.placeError = "frame-not-restored"
report = env:start(recipe({ "Ghostty" }))
env:drain()
equal(report.applied, 0, "an ignored placement is not success")
equal(#report.failures, 1, "record placement failure")
equal(report.failures[1].target.appName, "Ghostty", "identify failed application slot")
env = environment()
env.failCollect = true
report = env:start(layout)
equal(report.finished, true, "failed collection completes immediately")
equal(report.reason, "enumeration-failed", "collection error is explicit")
equal(#env.creates, 0, "failed collection must not trigger creation")
env = environment()
env.noNewWindow, env.failTimer = true, true
report = env:start(recipe({ "Ghostty" }))
env:drain()
equal(report.reason, "could-not-schedule-window-check", "timer allocation fails safely")

print(string.format("workspace_establish: %d assertions passed", assertions))
