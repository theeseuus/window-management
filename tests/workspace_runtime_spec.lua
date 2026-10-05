local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")

local assertions = 0

local function equal(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(
      string.format(
        "%s: expected %s, got %s",
        label,
        tostring(expected),
        tostring(actual)
      ),
      2
    )
  end
end

local function near(actual, expected, label)
  assertions = assertions + 1
  if math.abs(actual - expected) > 0.000001 then
    error(
      string.format(
        "%s: expected %.8f, got %.8f",
        label,
        expected,
        actual
      ),
      2
    )
  end
end

local screenFrame = { x = 100, y = 50, w = 1600, h = 1000 }
local screen = {}
function screen:id() return 1 end
function screen:frame()
  return {
    x = screenFrame.x,
    y = screenFrame.y,
    w = screenFrame.w,
    h = screenFrame.h,
  }
end

local function makeApplication(bundleID, title)
  local application = {}
  function application:bundleID() return bundleID end
  function application:title() return title end
  return application
end

local function makeWindow(id, application, frame, memberships)
  local window = {
    currentFrame = frame,
    memberships = memberships or { 901 },
    setCount = 0,
  }
  function window:id() return id end
  function window:isStandard() return true end
  function window:isVisible() return self.visible ~= false end
  function window:isMinimized() return false end
  function window:isFullScreen() return false end
  function window:screen() return screen end
  function window:application() return application end
  function window:frame()
    return {
      x = self.currentFrame.x,
      y = self.currentFrame.y,
      w = self.currentFrame.w,
      h = self.currentFrame.h,
    }
  end
  function window:setFrameInScreenBounds(frame)
    self.setCount = self.setCount + 1
    if self.ignoreFrameRequests then return self end
    self.currentFrame = {
      x = frame.x,
      y = frame.y,
      w = frame.w,
      h = frame.h,
    }
    return self
  end
  function window:setSize(size)
    if not self.ignoreFrameRequests then
      self.currentFrame.w = size.w
      self.currentFrame.h = size.h
    end
    return self
  end
  function window:setTopLeft(point)
    if not self.ignoreFrameRequests then
      self.currentFrame.x = point.x
      self.currentFrame.y = point.y
    end
    return self
  end
  function window:title()
    error("TheseusWorkspace must not inspect window titles")
  end
  return window
end

local safari = makeApplication("com.apple.Safari", "Safari")
local ghostty = makeApplication("com.mitchellh.ghostty", "Ghostty")
local finder = makeApplication("com.apple.finder", "Finder")

local windows = {
  [11] = makeWindow(11, safari, { x = 100, y = 50, w = 800, h = 1000 }),
  [21] = makeWindow(21, ghostty, { x = 900, y = 50, w = 800, h = 1000 }),
  [31] = makeWindow(31, finder, { x = 500, y = 300, w = 800, h = 500 }),
  [41] = makeWindow(
    41,
    finder,
    { x = 300, y = 200, w = 500, h = 400 },
    { 901, 902 }
  ),
}
local currentWindowIDs = { 11, 21, 41 }
local focusedWindow = windows[11]
local settings = {}
local alerts = {}
local timers = {}
local currentSpaceID = 901
local enumerationCount = 0

local function drainTimers()
  local steps = 0
  while #timers > 0 do
    steps = steps + 1
    if steps > 100 then error("restore timers must be bounded") end
    local timer = table.remove(timers, 1)
    if not timer.stopped then timer.callback() end
  end
end

local previousHs = hs
hs = {
  alert = {
    show = function(message)
      table.insert(alerts, message)
    end,
  },
  screen = {
    mainScreen = function() return screen end,
  },
  window = {
    focusedWindow = function() return focusedWindow end,
    get = function(id) return windows[id] end,
    allWindows = function()
      enumerationCount = enumerationCount + 1
      return { windows[11], windows[21], windows[31], windows[41] }
    end,
  },
  spaces = {
    activeSpaceOnScreen = function() return currentSpaceID end,
    spaceType = function() return "user" end,
    windowsForSpace = function() return currentWindowIDs end,
    windowSpaces = function(window) return window.memberships end,
  },
  settings = {
    get = function(key) return settings[key] end,
    set = function(key, value) settings[key] = value end,
  },
  timer = {
    doAfter = function(delay, callback)
      local timer = { delay = delay, callback = callback }
      function timer:stop() self.stopped = true end
      table.insert(timers, timer)
      return timer
    end,
  },
}

local workspace = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/init.lua"
)

equal(workspace.name, "TheseusWorkspace", "workspace Spoon name")
equal(workspace.version, "0.1.3", "workspace Spoon version")
equal(workspace.author, "Theeseuus", "workspace Spoon author")

local recipe, captureReport = workspace:captureCurrentWorkspace(
  "Project Atlas",
  { silent = true }
)
equal(recipe.name, "Project Atlas", "capture recipe name")
equal(captureReport.captured, 2, "capture eligible windows")
equal(captureReport.enumerated, 3, "capture enumerated windows")
equal(captureReport.skippedCount, 1, "capture skipped window count")
equal(captureReport.skipped["not-exclusive-to-current-space"], 1, "skip sticky window")
equal(enumerationCount, 1, "capture enumerates application windows only once")
equal(#settings.TheseusWorkspaceRecipesV1.recipes["Project Atlas"].windows, 2, "persist recipe")
equal(
  settings.TheseusWorkspaceRecipesV1.recipes["Project Atlas"].windows[1].title,
  nil,
  "do not persist window title"
)

local duplicate, duplicateErr = workspace:captureCurrentWorkspace(
  "Project Atlas",
  { silent = true }
)
equal(duplicate, nil, "capture refuses implicit replacement")
equal(duplicateErr, "workspace-exists", "implicit replacement error")

windows[11].currentFrame = { x = 900, y = 550, w = 400, h = 500 }
windows[21].currentFrame = { x = 100, y = 50, w = 400, h = 500 }
currentWindowIDs = { 11, 21, 31, 41 }

local completedCount = 0
local restoreReport = workspace:restoreWorkspace("Project Atlas", {
  silent = true,
  onComplete = function(report)
    completedCount = completedCount + 1
    equal(report.finished, true, "callback sees a completed report")
  end,
})
equal(restoreReport.applied, 0, "requests are not counted before verification")
equal(restoreReport.pending, 2, "restore checks are pending")
equal(restoreReport.finished, false, "restore initially remains in progress")
local concurrent, concurrentErr = workspace:restoreWorkspace("Project Atlas", { silent = true })
equal(concurrent, nil, "reject an overlapping restore")
equal(concurrentErr, "restore-in-progress", "overlapping restore error")
drainTimers()
equal(completedCount, 1, "complete the batch exactly once")
equal(restoreReport.finished, true, "restore finishes after frame checks")
equal(restoreReport.pending, 0, "restore has no pending checks")
equal(workspace.lastRestoreReport, restoreReport, "retain the last completion report")
equal(restoreReport.applied, 2, "restore matching windows")
equal(#restoreReport.missing, 0, "restore has no missing windows")
equal(#restoreReport.extras, 1, "restore reports unrelated extra window")
equal(#restoreReport.failures, 0, "restore has no frame failures")
near(windows[11].currentFrame.x, 100, "restore Safari x")
near(windows[11].currentFrame.w, 800, "restore Safari width")
near(windows[21].currentFrame.x, 900, "restore Ghostty x")
near(windows[21].currentFrame.w, 800, "restore Ghostty width")
equal(windows[31].setCount, 0, "leave extra Finder window untouched")
equal(windows[41].setCount, 0, "leave sticky Finder window untouched")

windows[21].currentFrame = { x = 100, y = 50, w = 400, h = 500 }
windows[21].ignoreFrameRequests = true
local ignoredReport = workspace:restoreWorkspace("Project Atlas")
equal(#alerts, 0, "do not announce success before frame checks")
drainTimers()
equal(ignoredReport.applied, 1, "an ignored Ghostty move is not reported as placed")
equal(#ignoredReport.failures, 1, "an ignored Ghostty move is reported as a failure")
equal(ignoredReport.failures[1].reason, "frame-not-restored", "ignored frame failure reason")
equal(ignoredReport.failures[1].target.appName, "Ghostty", "name the failing application")
equal(alerts[1]:find("Failed: Ghostty", 1, true) ~= nil, true, "alert names Ghostty")
near(windows[21].currentFrame.x, 100, "quietly ignored requests leave Ghostty unchanged")
windows[21].ignoreFrameRequests = false

currentWindowIDs = { 11, 31, 41 }
local partialReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
drainTimers()
equal(partialReport.applied, 1, "partial restore applies available window")
equal(#partialReport.missing, 1, "partial restore reports missing slot")
equal(partialReport.missing[1].bundleID, "com.mitchellh.ghostty", "missing Ghostty slot")
equal(#partialReport.extras, 1, "partial restore retains Finder extra")

currentWindowIDs = { 31, 41 }
local allMissingReport = workspace:restoreWorkspace("Project Atlas")
equal(allMissingReport.finished, true, "a batch with no candidates finishes immediately")
equal(allMissingReport.pending, 0, "a batch with no candidates has no timers")
equal(allMissingReport.applied, 0, "a missing-only batch places no windows")
equal(#allMissingReport.missing, 2, "a missing-only batch reports both slots")
equal(alerts[2]:find("Missing: Ghostty, Safari", 1, true) ~= nil, true, "name missing apps")
equal(windows[31].setCount, 0, "missing-only restore still leaves the extra untouched")

currentWindowIDs = { 11, 21, 31, 41 }
local cancelledReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
workspace:stop()
drainTimers()
equal(cancelledReport.finished, true, "stopping finishes the cancellation report")
equal(cancelledReport.cancelled, true, "stopping marks the restore as cancelled")
equal(cancelledReport.pending, 0, "stopping clears all pending work")
equal(#cancelledReport.failures, 2, "stopping cancels both unverified placements")

local spaceChangedReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
currentSpaceID = 902
local setCountBefore = windows[21].setCount
drainTimers()
equal(spaceChangedReport.applied, 0, "do not verify a restore after leaving its Space")
equal(#spaceChangedReport.failures, 2, "Space change stops remaining checks")
equal(spaceChangedReport.failures[1].reason, "active-space-changed", "Space change reason")
equal(windows[21].setCount, setCountBefore, "do not retry in the wrong Space")
currentSpaceID = 901

windows[21].ignoreFrameRequests = true
windows[21].currentFrame = { x = 100, y = 50, w = 400, h = 500 }
local hiddenReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
windows[21].visible = false
setCountBefore = windows[21].setCount
drainTimers()
equal(hiddenReport.applied, 1, "available Safari can still complete")
equal(hiddenReport.failures[1].reason, "not-visible", "recheck visibility before retry")
equal(windows[21].setCount, setCountBefore, "do not retry a now-hidden Ghostty window")
windows[21].visible = true
windows[21].ignoreFrameRequests = false

local listed = workspace:listWorkspaces()
equal(#listed, 1, "list captured workspace")
equal(listed[1].name, "Project Atlas", "listed workspace name")
equal(listed[1].windowCount, 2, "listed workspace window count")
equal(listed[1].applications, "Ghostty, Safari", "listed workspace applications")

equal(workspace:deleteWorkspace("Project Atlas", { silent = true }), true, "delete workspace")
equal(#workspace:listWorkspaces(), 0, "deleted workspace leaves empty catalog")
local missingRestore, missingRestoreErr = workspace:restoreWorkspace(
  "Project Atlas",
  { silent = true }
)
equal(missingRestore, nil, "deleted workspace cannot restore")
equal(missingRestoreErr, "workspace-not-found", "deleted workspace restore error")
equal(#alerts, 2, "only non-silent restores produce alerts")

hs = previousHs

print(string.format("workspace_runtime_spec: %d assertions passed", assertions))
