----------------------------------------------------------------------
-- FILE 1: ~/.hammerspoon/Spoons/TheseusWindow.spoon/init.lua
-- TheseusWindow Spoon
-- Deterministic window cycling + simple HUD + meso controls
-- + Native Space move-and-follow + centred arrow layout/restore
-- + Centre-preserving focused-window width adjustment
-- + Accordion layout (fan windows of active app from focused window)
-- + Cross-app window switcher (Hyper+W / Hyper+Shift+W) with UI
----------------------------------------------------------------------

local obj = {}
obj.__index = obj

obj.name = "TheseusWindow"
obj.version = "0.4"
obj.author = "Theeseuus"
obj.license = "MIT"

-- Hyper keys (Raycast-style)
obj.hyper      = {"ctrl", "alt", "cmd"}
obj.hyperShift = {"ctrl", "alt", "cmd", "shift"}

-- User configuration
obj.showSpaceIndicator       = false
obj.widthStep                = 80
obj.minWindowWidth           = 360
obj.maxWindowWidthRatio      = 1.0
obj.spaceMovePollInterval    = 0.05
obj.spaceMoveTimeout         = 2.0
obj.spaceFocusTimeout        = 1.5
obj.spaceNativeGrabDelay     = 0.15
obj.spaceNativeKeyInterval   = 0.05
obj.spaceNativeReleaseDelay = 1.8

local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local spaceLogic = dofile(sourcePath .. "space_logic.lua")
local cycleLogic = dofile(sourcePath .. "cycle_logic.lua")
local nativeSpaceMove = dofile(sourcePath .. "native_space_move.lua")

------------------------------------------------------------
-- HUD (robust): hs.alert
------------------------------------------------------------
local function showAlert(text, win, duration)
  local screen
  if win then
    local screenOK, windowScreen = pcall(function()
      return win:screen()
    end)
    if screenOK then
      screen = windowScreen
    end
  end
  screen = screen or hs.screen.mainScreen()
  if not screen then return end
  hs.alert.closeAll()
  hs.alert.show(
    text,
    { strokeWidth = 0, fillColor = { alpha = 0.85 } },
    screen,
    duration or 1.0
  )
end

local function showHUD(win, text)
  showAlert(text, win, 0.6)
end

------------------------------------------------------------
-- State
------------------------------------------------------------
local cycleState   = {}   -- winId -> cycle index
local restoreState = {}   -- winId -> frame (for Hyper+Down restore)
local stashState   = {}   -- winId -> { frame = ... } (stash/unstash)
local activeSpaceMove

------------------------------------------------------------
-- Cycle engine (forward starts at 1; reverse starts at the final index)
------------------------------------------------------------
local function cycleWindow(win, positions, step, label)
  step = step or 1
  local id = win:id()
  local n  = #positions

  local idx = cycleLogic.nextIndex(cycleState[id], n, step)

  cycleState[id] = idx
  win:setFrame(positions[idx](win:screen()))

  local arrow = (step >= 0) and "↻" or "↺"
  local tag = label or "•"
  showHUD(win, string.format("%s %s %d/%d", tag, arrow, idx, n))
end

-- Arrow layout/restore helpers
------------------------------------------------------------
local function saveRestoreFrame(win)
  if not win then return end
  local frame = win:frame()
  restoreState[win:id()] = {
    x = frame.x,
    y = frame.y,
    w = frame.w,
    h = frame.h
  }
end

local function centerHalfWidth(win)
  local s = win:screen()
  if not s then return end
  local f = s:frame()
  local width = f.w * 0.50
  win:setFrame({
    x = f.x + (f.w - width) / 2,
    y = f.y,
    w = width,
    h = f.h
  })
  showHUD(win, "CENTER")
end

local function restoreWindow(win)
  if not win then return end
  local fr = restoreState[win:id()]
  if fr then
    win:setFrame(fr)
    showHUD(win, "RESTORE")
  else
    -- Fallback: centred, nearly maximized frame
    local f = win:screen():frame()
    local ww, hh = f.w * 0.85, f.h * 0.90
    win:setFrame({
      x = f.x + (f.w - ww) / 2,
      y = f.y + (f.h - hh) / 2,
      w = ww,
      h = hh
    })
    showHUD(win, "CENTER")
  end
end

------------------------------------------------------------
-- Focused-window width adjustment
------------------------------------------------------------
local function resizeFocusedWindowWidth(controller, direction)
  local win = hs.window.focusedWindow()
  if not win then
    showAlert("WIDTH: no focused window")
    return
  end
  if not win:isStandard() or win:isMinimized() or win:isFullScreen() then
    showAlert("WIDTH: focused window cannot be resized", win)
    return
  end

  local screen = win:screen()
  if not screen then
    showAlert("WIDTH: focused window has no screen", win)
    return
  end

  local frame = win:frame()
  local screenFrame = screen:frame()
  local step = math.max(1, tonumber(controller.widthStep) or 80)
  local maximumRatio = tonumber(controller.maxWindowWidthRatio) or 1.0
  maximumRatio = math.max(0.1, math.min(1.0, maximumRatio))

  local maximumWidth = screenFrame.w * maximumRatio
  local minimumWidth = tonumber(controller.minWindowWidth) or 360
  minimumWidth = math.max(1, math.min(minimumWidth, maximumWidth))

  local newWidth = frame.w + (direction * step)
  newWidth = math.max(minimumWidth, math.min(maximumWidth, newWidth))

  local centreX = frame.x + (frame.w / 2)
  local newX = centreX - (newWidth / 2)
  newX = math.max(screenFrame.x, newX)
  newX = math.min(screenFrame.x + screenFrame.w - newWidth, newX)

  win:setFrame({
    x = newX,
    y = frame.y,
    w = newWidth,
    h = frame.h
  })
  showHUD(win, string.format("WIDTH %d", math.floor(newWidth + 0.5)))
end

------------------------------------------------------------
-- Native Space move-and-follow
------------------------------------------------------------
local function copyFrame(frame)
  return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function orderedUserSpaces(screen)
  local callOK, orderedSpaces, err = pcall(hs.spaces.spacesForScreen, screen)
  if not callOK then
    return nil, "could not read ordered Spaces: " .. tostring(orderedSpaces)
  end
  if not orderedSpaces then
    return nil, "could not read ordered Spaces: " .. tostring(err)
  end

  return spaceLogic.userSpaces(orderedSpaces, function(spaceID)
    local typeOK, spaceType, typeErr = pcall(hs.spaces.spaceType, spaceID)
    if not typeOK then
      return nil, tostring(spaceType)
    end
    return spaceType, typeErr
  end)
end

local function finishSpaceMove(operation, message, isFailure)
  if operation.timer then
    operation.timer:stop()
    operation.timer = nil
  end
  if operation.transport then
    operation.transport:cancel()
    operation.transport = nil
  end
  if activeSpaceMove == operation then
    activeSpaceMove = nil
  end

  if isFailure then
    showAlert("SPACE: " .. message, operation.window, 1.5)
  else
    showHUD(operation.window, message)
  end
end

local function pollSpaceMove(operation, timeout, check, onReady, timeoutMessage)
  local deadline = hs.timer.secondsSinceEpoch() + timeout
  local timer

  local function tick()
    if activeSpaceMove ~= operation then
      timer:stop()
      return
    end

    local checkOK, ready, checkErr = pcall(check)
    if not checkOK then
      finishSpaceMove(operation, tostring(ready), true)
      return
    end
    if checkErr then
      finishSpaceMove(operation, tostring(checkErr), true)
      return
    end
    if ready then
      timer:stop()
      if operation.timer == timer then
        operation.timer = nil
      end
      local readyOK, readyErr = pcall(onReady)
      if not readyOK and activeSpaceMove == operation then
        finishSpaceMove(operation, "operation failed: " .. tostring(readyErr), true)
      end
      return
    end
    if hs.timer.secondsSinceEpoch() >= deadline then
      local message = timeoutMessage
      if type(timeoutMessage) == "function" then
        message = timeoutMessage()
      end
      finishSpaceMove(operation, message, true)
    end
  end

  timer = hs.timer.doEvery(operation.pollInterval, tick)
  operation.timer = timer
  tick()
end

local function focusMovedWindow(operation)
  local frameOK, frameErr = pcall(function()
    operation.window:setFrame(operation.originalFrame, 0)
  end)
  if not frameOK then
    operation.warning = "moved and followed, but frame restore failed: " .. tostring(frameErr)
  end

  local firstFocusOK, firstFocusErr = pcall(function()
    operation.window:focus()
  end)
  if not firstFocusOK then
    finishSpaceMove(
      operation,
      "moved and followed, but refocus failed: " .. tostring(firstFocusErr),
      true
    )
    return
  end

  pollSpaceMove(
    operation,
    operation.focusTimeout,
    function()
      local focused = hs.window.focusedWindow()
      if focused and focused:id() == operation.windowID then
        return true
      end

      local retryOK, retryErr = pcall(function()
        operation.window:focus()
      end)
      if not retryOK then
        return false, "refocus failed: " .. tostring(retryErr)
      end
      return false
    end,
    function()
      if operation.warning then
        finishSpaceMove(operation, operation.warning, true)
      else
        local arrow = operation.direction < 0 and "←" or "→"
        finishSpaceMove(
          operation,
          string.format("%s SPACE %d", arrow, operation.destinationOrdinal),
          false
        )
      end
    end,
    "moved and followed, but could not refocus the exact window"
  )
end

local function verifyNativeSpaceMove(operation)
  pollSpaceMove(
    operation,
    operation.moveTimeout,
    function()
      local spacesOK, spaces, spacesErr = pcall(
        hs.spaces.windowSpaces,
        operation.window
      )
      if not spacesOK then
        return false, "could not verify window move: " .. tostring(spaces)
      end
      if not spaces then
        return false, "could not verify window move: " .. tostring(spacesErr)
      end
      operation.windowReachedDestination =
        spaceLogic.contains(spaces, operation.destinationSpace)

      local activeOK, activeSpace, activeErr = pcall(
        hs.spaces.activeSpaceOnScreen,
        operation.screen
      )
      if not activeOK then
        return false, "could not verify destination Space: " .. tostring(activeSpace)
      end
      if not activeSpace then
        return false, "could not verify destination Space: " .. tostring(activeErr)
      end
      operation.destinationBecameActive =
        activeSpace == operation.destinationSpace

      return operation.windowReachedDestination
        and operation.destinationBecameActive
    end,
    function()
      focusMovedWindow(operation)
    end,
    function()
      if operation.destinationBecameActive
        and not operation.windowReachedDestination then
        return "switched Spaces, but the exact window did not move"
      end
      if operation.windowReachedDestination
        and not operation.destinationBecameActive then
        return "window moved, but the destination Space did not become active"
      end
      return "native move-and-follow was not confirmed"
    end
  )
end

local function moveFocusedWindowToAdjacentSpace(controller, direction)
  if activeSpaceMove then
    showAlert("SPACE: a window move is already in progress", activeSpaceMove.window)
    return
  end

  local win = hs.window.focusedWindow()
  if not win then
    showAlert("SPACE: no focused window")
    return
  end
  if win:isMinimized() then
    showAlert("SPACE: minimized windows cannot be moved", win)
    return
  end
  if win:isFullScreen() then
    showAlert("SPACE: full-screen windows cannot be moved", win)
    return
  end
  if not win:isStandard() or not win:isVisible() then
    showAlert("SPACE: focus a standard movable window", win)
    return
  end

  local screen = win:screen()
  if not screen then
    showAlert("SPACE: focused window has no screen", win)
    return
  end

  local activeOK, currentSpace, activeErr = pcall(
    hs.spaces.activeSpaceOnScreen,
    screen
  )
  if not activeOK then
    showAlert("SPACE: could not determine current Space: " .. tostring(currentSpace), win)
    return
  end
  if not currentSpace then
    showAlert("SPACE: could not determine current Space: " .. tostring(activeErr), win)
    return
  end

  local typeOK, currentType, typeErr = pcall(hs.spaces.spaceType, currentSpace)
  if not typeOK or currentType ~= "user" then
    local reason = typeOK and currentType or typeErr
    showAlert("SPACE: current Space is not a movable user Space: " .. tostring(reason), win)
    return
  end

  local membershipOK, windowSpaces, membershipErr = pcall(hs.spaces.windowSpaces, win)
  if not membershipOK then
    showAlert("SPACE: could not determine window Space: " .. tostring(windowSpaces), win)
    return
  end
  if not windowSpaces then
    showAlert("SPACE: could not determine window Space: " .. tostring(membershipErr), win)
    return
  end
  if #windowSpaces ~= 1 then
    showAlert("SPACE: windows present on multiple Spaces are not moved", win)
    return
  end
  if windowSpaces[1] ~= currentSpace then
    showAlert("SPACE: focused window is not on the active Space", win)
    return
  end

  local userSpaces, userSpacesErr = orderedUserSpaces(screen)
  if not userSpaces then
    showAlert("SPACE: " .. tostring(userSpacesErr), win)
    return
  end

  local destinationSpace, adjacentErr, destinationOrdinal =
    spaceLogic.adjacent(userSpaces, currentSpace, direction)
  if not destinationSpace then
    if adjacentErr == "boundary" then
      local edge = direction < 0 and "first" or "last"
      showAlert("SPACE: already at the " .. edge .. " user Space", win)
    else
      showAlert("SPACE: active user Space is missing from the ordered list", win)
    end
    return
  end

  local operation = {
    window = win,
    windowID = win:id(),
    screen = screen,
    originalFrame = copyFrame(win:frame()),
    destinationSpace = destinationSpace,
    destinationOrdinal = destinationOrdinal,
    direction = direction,
    pollInterval = math.max(0.01, tonumber(controller.spaceMovePollInterval) or 0.05),
    moveTimeout = math.max(0.1, tonumber(controller.spaceMoveTimeout) or 2.0),
    focusTimeout = math.max(0.1, tonumber(controller.spaceFocusTimeout) or 1.5)
  }
  activeSpaceMove = operation

  local moveOK, movement, moveErr = pcall(
    nativeSpaceMove.start,
    win,
    direction,
    {
      grabDelay = controller.spaceNativeGrabDelay,
      keyInterval = controller.spaceNativeKeyInterval,
      releaseDelay = controller.spaceNativeReleaseDelay
    },
    function(nativeOK, nativeErr)
      if activeSpaceMove ~= operation then return end
      if not nativeOK then
        finishSpaceMove(
          operation,
          "native window move failed: " .. tostring(nativeErr),
          true
        )
        return
      end
      verifyNativeSpaceMove(operation)
    end
  )
  if not moveOK then
    finishSpaceMove(
      operation,
      "could not start native window move: " .. tostring(movement),
      true
    )
    return
  end
  if not movement then
    finishSpaceMove(
      operation,
      "could not start native window move: " .. tostring(moveErr),
      true
    )
    return
  end
  operation.transport = movement
end

------------------------------------------------------------
-- Stash helpers (toggle)
------------------------------------------------------------
local function moveOffscreen(win)
  local s = win:screen()
  if not s then return end
  local sf = s:frame()
  local wf = win:frame()
  -- Move just beyond the right edge of the current screen
  win:setFrame({ x = sf.x + sf.w + 40, y = wf.y, w = wf.w, h = wf.h })
end

local function toggleStash(win)
  if not win then return end
  local id = win:id()

  if stashState[id] then
    local fr = stashState[id].frame
    stashState[id] = nil
    win:setFrame(fr)
    showHUD(win, "UNSTASH")
  else
    stashState[id] = { frame = win:frame() }
    moveOffscreen(win)
    showHUD(win, "STASH")
  end
end

------------------------------------------------------------
-- Accordion helpers (fan windows of active app from focused)
------------------------------------------------------------
local function isGoodWindow(w)
  return w and w:isStandard() and w:isVisible()
end

local function clampFrameToScreen(frame, screenFrame)
  local f = hs.geometry.rect(frame)
  if f.x < screenFrame.x then f.x = screenFrame.x end
  if f.y < screenFrame.y then f.y = screenFrame.y end
  local maxX = screenFrame.x + screenFrame.w - f.w
  local maxY = screenFrame.y + screenFrame.h - f.h
  if f.x > maxX then f.x = maxX end
  if f.y > maxY then f.y = maxY end
  return f
end

local function accordionActiveAppFromFocused(opts)
  opts = opts or {}
  local offsetX       = opts.offsetX or 28
  local offsetY       = opts.offsetY or 22
  local clampToScreen = (opts.clampToScreen ~= false) -- default true

  local focused = hs.window.focusedWindow()
  if not isGoodWindow(focused) then return end

  local app = focused:application()
  if not app then return end

  local base = focused:frame()        -- anchor frame (size + position)
  local sf   = focused:screen():frame()

  -- collect other windows in the same app
  local others = {}
  for _, w in ipairs(app:allWindows()) do
    if isGoodWindow(w) and w:id() ~= focused:id() then
      table.insert(others, w)
    end
  end

  if #others == 0 then
    showHUD(focused, "ACC 1")
    return
  end

  -- stable ordering: top-to-bottom, left-to-right (so fan is predictable)
  table.sort(others, function(a, b)
    local fa, fb = a:frame(), b:frame()
    if fa.y == fb.y then return fa.x < fb.x end
    return fa.y < fb.y
  end)

  -- apply fan; do NOT touch focused window
  for i, w in ipairs(others) do
    local newFrame = {
      x = base.x + i * offsetX,
      y = base.y + i * offsetY,
      w = base.w,
      h = base.h
    }
    if clampToScreen then
      newFrame = clampFrameToScreen(newFrame, sf)
    end
    w:setFrame(newFrame)
  end

  -- restore focus to avoid disturbing macOS cmd+` cycling order too much
  focused:focus()
  showHUD(focused, string.format("ACC %d", #others + 1))
end

------------------------------------------------------------
-- Cross-app window switcher (UI, cross-Space)
------------------------------------------------------------
local windowFilter = hs.window.filter.new()
windowFilter:setOverrideFilter({
  allowRoles = { "AXStandardWindow" }
})

local windowSwitcher = hs.window.switcher.new(windowFilter)

-- UI tuning (restrained; adjust if you want bigger previews)
windowSwitcher.ui.showTitles = true
windowSwitcher.ui.showThumbnails = true
windowSwitcher.ui.thumbnailSize = 120
windowSwitcher.ui.showSelectedThumbnail = true
windowSwitcher.ui.backgroundColor = { alpha = 0.90 }
windowSwitcher.ui.highlightColor = { white = 1, alpha = 0.25 }
windowSwitcher.ui.textColor = { white = 1 }
windowSwitcher.ui.fontSize = 13

------------------------------------------------------------
-- Position definitions (micro cycles)
------------------------------------------------------------

-- 2: Halves (Left ↔ Right) — anchor = Left
local halves = {
  function(s)
    local f = s:frame()
    return { x = f.x, y = f.y, w = f.w / 2, h = f.h }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h }
  end,
}

-- 3: Thirds (Left → Center → Right) — anchor = Left
local thirds = {
  function(s)
    local f = s:frame()
    return { x = f.x, y = f.y, w = f.w / 3, h = f.h }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x + f.w / 3, y = f.y, w = f.w / 3, h = f.h }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x + 2 * f.w / 3, y = f.y, w = f.w / 3, h = f.h }
  end,
}

-- 4: Quarters clockwise (TL → TR → BR → BL) — anchor = TL
local quarters = {
  function(s)
    local f = s:frame()
    return { x = f.x, y = f.y, w = f.w / 2, h = f.h / 2 }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x + f.w / 2, y = f.y, w = f.w / 2, h = f.h / 2 }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x + f.w / 2, y = f.y + f.h / 2, w = f.w / 2, h = f.h / 2 }
  end,
  function(s)
    local f = s:frame()
    return { x = f.x, y = f.y + f.h / 2, w = f.w / 2, h = f.h / 2 }
  end,
}

-- 8: Eighths clockwise perimeter (4×2)
-- TL → T2 → T3 → TR → BR → B3 → B2 → BL → (back to TL)
local eighths = {
  function(s) local f=s:frame(); return {x=f.x+0*f.w/4,y=f.y,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+1*f.w/4,y=f.y,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+2*f.w/4,y=f.y,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+3*f.w/4,y=f.y,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+3*f.w/4,y=f.y+f.h/2,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+2*f.w/4,y=f.y+f.h/2,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x+1*f.w/4,y=f.y+f.h/2,w=f.w/4,h=f.h/2} end,
  function(s) local f=s:frame(); return {x=f.x,y=f.y+f.h/2,w=f.w/4,h=f.h/2} end,
}

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function obj:updateSpaceIndicator()
  if not self._spaceIndicator then return end

  local screen = hs.screen.mainScreen()
  if not screen then
    self._spaceIndicator:setTitle("Space ?")
    self._spaceIndicator:setTooltip("No active screen")
    return
  end

  local activeOK, activeSpace, activeErr = pcall(hs.spaces.activeSpaceOnScreen, screen)
  if not activeOK or not activeSpace then
    local reason = activeOK and activeErr or activeSpace
    self._spaceIndicator:setTitle("Space ?")
    self._spaceIndicator:setTooltip("Could not read active Space: " .. tostring(reason))
    return
  end

  local userSpaces, userSpacesErr = orderedUserSpaces(screen)
  if not userSpaces then
    self._spaceIndicator:setTitle("Space ?")
    self._spaceIndicator:setTooltip(tostring(userSpacesErr))
    return
  end

  local ordinal, count = spaceLogic.ordinal(userSpaces, activeSpace)
  if ordinal then
    self._spaceIndicator:setTitle("Space " .. tostring(ordinal))
    self._spaceIndicator:setTooltip(
      string.format("Active user Space %d of %d", ordinal, count)
    )
  else
    self._spaceIndicator:setTitle("Space —")
    self._spaceIndicator:setTooltip("Active Space is full-screen or tiled")
  end
end

function obj:_scheduleSpaceIndicatorUpdate()
  if self._spaceIndicatorUpdateTimer then
    self._spaceIndicatorUpdateTimer:stop()
  end
  self._spaceIndicatorUpdateTimer = hs.timer.doAfter(0.1, function()
    self._spaceIndicatorUpdateTimer = nil
    self:updateSpaceIndicator()
  end)
end

function obj:_stopSpaceIndicator()
  if self._spaceIndicatorUpdateTimer then
    self._spaceIndicatorUpdateTimer:stop()
    self._spaceIndicatorUpdateTimer = nil
  end
  if self._spaceWatcher then
    self._spaceWatcher:stop()
    self._spaceWatcher = nil
  end
  if self._spaceIndicator then
    self._spaceIndicator:delete()
    self._spaceIndicator = nil
  end
end

function obj:start()
  self:_stopSpaceIndicator()
  if not self.showSpaceIndicator then
    return self
  end

  self._spaceIndicator = hs.menubar.new()
  if not self._spaceIndicator then
    hs.printf("TheseusWindow: could not create Space menu-bar indicator")
    return self
  end

  self:updateSpaceIndicator()
  self._spaceWatcher = hs.spaces.watcher.new(function()
    self:_scheduleSpaceIndicatorUpdate()
  end):start()
  return self
end

function obj:stop()
  self:_stopSpaceIndicator()
  if activeSpaceMove and activeSpaceMove.timer then
    activeSpaceMove.timer:stop()
  end
  if activeSpaceMove and activeSpaceMove.transport then
    activeSpaceMove.transport:cancel()
  end
  activeSpaceMove = nil
  return self
end

function obj:moveFocusedWindowToAdjacentSpace(direction)
  moveFocusedWindowToAdjacentSpace(self, direction)
  return self
end

function obj:bindHotkeys()
  local h      = self.hyper
  local hshift = self.hyperShift

  -- Cross-app window cycling (jumps Spaces implicitly)
  -- Hyper + W / Hyper + Shift + W
  hs.hotkey.bind(h, "w", function()
    windowSwitcher:next()
  end)

  hs.hotkey.bind(hshift, "w", function()
    windowSwitcher:previous()
  end)

  -- Micro cycles (forward + reverse).
  -- A fresh reverse cycle starts at its final position.
  hs.hotkey.bind(h, "2", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, halves, 1, "2") end
  end)
  hs.hotkey.bind(hshift, "2", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, halves, -1, "2") end
  end)

  hs.hotkey.bind(h, "3", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, thirds, 1, "3") end
  end)
  hs.hotkey.bind(hshift, "3", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, thirds, -1, "3") end
  end)

  hs.hotkey.bind(h, "4", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, quarters, 1, "4") end
  end)
  hs.hotkey.bind(hshift, "4", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, quarters, -1, "4") end
  end)

  hs.hotkey.bind(h, "8", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, eighths, 1, "8") end
  end)
  hs.hotkey.bind(hshift, "8", function()
    local w = hs.window.focusedWindow()
    if w then cycleWindow(w, eighths, -1, "8") end
  end)

  -- Stash toggle: Hyper + S
  hs.hotkey.bind(h, "s", function()
    local w = hs.window.focusedWindow()
    if w then toggleStash(w) end
  end)

  -- Accordion: Hyper + Shift + S
  -- Uses focused window as the anchor; does NOT resize/move it.
  -- All other standard visible windows in the same app match its size and fan out.
  hs.hotkey.bind(hshift, "s", function()
    accordionActiveAppFromFocused({
      offsetX = 28,
      offsetY = 22,
      clampToScreen = true
    })
  end)

  -- Spatial arrows:
  -- Control+Left/Right moves only the user (native macOS, not bound here).
  -- Hyper+Left/Right moves the focused window to an adjacent user Space,
  -- follows it, and refocuses that exact window.
  hs.hotkey.bind(h, "left", function()
    self:moveFocusedWindowToAdjacentSpace(-1)
  end)

  hs.hotkey.bind(h, "right", function()
    self:moveFocusedWindowToAdjacentSpace(1)
  end)

  -- Hyper+Up = centred half-width/full-height; Hyper+Down = restore.
  hs.hotkey.bind(h, "up", function()
    local w = hs.window.focusedWindow()
    if not w then return end
    saveRestoreFrame(w)
    centerHalfWidth(w)
  end)

  hs.hotkey.bind(h, "down", function()
    local w = hs.window.focusedWindow()
    if w then restoreWindow(w) end
  end)

  -- Hyper+[ / Hyper+] = narrow/widen around the window centre.
  -- These keys no longer traverse Spaces; native Control+Left/Right does that.
  hs.hotkey.bind(h, "[", function()
    resizeFocusedWindowWidth(self, -1)
  end)

  hs.hotkey.bind(h, "]", function()
    resizeFocusedWindowWidth(self, 1)
  end)

  -- Meso controls
  -- Hyper + Return → Center column (50% width), full height
  hs.hotkey.bind(h, "return", function()
    local w = hs.window.focusedWindow()
    if w then centerHalfWidth(w) end
  end)

  -- Hyper + Shift + Return → Maximize
  hs.hotkey.bind(hshift, "return", function()
    local w = hs.window.focusedWindow()
    if w then w:maximize(); showHUD(w, "MAX") end
  end)

  -- Hyper + D → Minimize
  hs.hotkey.bind(h, "d", function()
    local w = hs.window.focusedWindow()
    if w then w:minimize() end
  end)

  return self
end

return obj
