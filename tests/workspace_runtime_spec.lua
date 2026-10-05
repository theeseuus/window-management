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
  function window:isVisible() return true end
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
    self.currentFrame = {
      x = frame.x,
      y = frame.y,
      w = frame.w,
      h = frame.h,
    }
    self.setCount = self.setCount + 1
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
  },
  spaces = {
    activeSpaceOnScreen = function() return 901 end,
    spaceType = function() return "user" end,
    windowsForSpace = function() return currentWindowIDs end,
    windowSpaces = function(window) return window.memberships end,
  },
  settings = {
    get = function(key) return settings[key] end,
    set = function(key, value) settings[key] = value end,
  },
}

local workspace = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/init.lua"
)

equal(workspace.name, "TheseusWorkspace", "workspace Spoon name")
equal(workspace.version, "0.1", "workspace Spoon version")
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

local restoreReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
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

currentWindowIDs = { 11, 31, 41 }
local partialReport = workspace:restoreWorkspace("Project Atlas", { silent = true })
equal(partialReport.applied, 1, "partial restore applies available window")
equal(#partialReport.missing, 1, "partial restore reports missing slot")
equal(partialReport.missing[1].bundleID, "com.mitchellh.ghostty", "missing Ghostty slot")
equal(#partialReport.extras, 1, "partial restore retains Finder extra")

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
equal(#alerts, 0, "silent runtime operations show no alerts")

hs = previousHs

print(string.format("workspace_runtime_spec: %d assertions passed", assertions))
