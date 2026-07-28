----------------------------------------------------------------------
-- Native Space move-and-follow transport
--
-- macOS moves a dragged window with the user when a native
-- Control+Left/Right Space transition occurs. Hammerspoon's direct
-- hs.spaces move/switch APIs are currently broken on macOS 27, so this
-- helper performs that native interaction and leaves verification,
-- focus restoration, and failure reporting to TheseusWindow.
----------------------------------------------------------------------

local transport = {}

local Event = hs.eventtap.event
local EventTypes = hs.eventtap.event.types
local Keycodes = hs.keycodes.map

local function postKey(keycode, isDown, flags)
  local event = Event.newKeyEvent(keycode, isDown)
  if flags then
    event:setFlags(flags)
  end
  event:post()
end

local function postMouse(eventType, point)
  Event.newMouseEvent(eventType, point):post()
end

local function schedule(state, delay, action)
  local timer = hs.timer.doAfter(delay, function()
    if state.cancelled or state.finished then return end

    local ok, err = pcall(action)
    if not ok then
      state:fail("native input failed: " .. tostring(err))
    end
  end)
  table.insert(state.timers, timer)
  return timer
end

local function restoreMouse(state)
  if state.mouseOrigin then
    hs.mouse.absolutePosition(state.mouseOrigin)
  end
end

local function releaseMouse(state)
  if not state.mouseDown then return end
  postMouse(EventTypes.leftMouseUp, hs.mouse.absolutePosition())
  state.mouseDown = false
end

local function stopTimers(state)
  for _, timer in ipairs(state.timers) do
    timer:stop()
  end
  state.timers = {}
end

local function finish(state, ok, err)
  if state.finished then return end
  state.finished = true
  stopTimers(state)

  local releaseOK, releaseErr = pcall(releaseMouse, state)
  local restoreOK, restoreErr = pcall(restoreMouse, state)

  if not releaseOK then
    ok = false
    err = "could not release the window: " .. tostring(releaseErr)
  elseif not restoreOK then
    ok = false
    err = "could not restore the pointer: " .. tostring(restoreErr)
  end

  if state.callback then
    state.callback(ok, err)
  end
end

local function postNativeSpaceSequence(state)
  local interval = state.keyInterval
  local arrow = state.direction < 0 and Keycodes.left or Keycodes.right

  -- The triggering Hyper chord is still physically down when its callback
  -- begins. Release that chord in the synthetic event stream before emitting
  -- the native Control+Arrow sequence, otherwise macOS sees Hyper+Arrow.
  postKey(arrow, false, {})
  postKey(Keycodes.cmd, false, {})
  postKey(Keycodes.alt, false, {})
  postKey(Keycodes.shift, false, {})
  postKey(Keycodes.ctrl, false, {})

  -- macOS 27 ignores the legacy single-event "Ctrl+Arrow" shortcut. Emit the
  -- modifier and arrow as the full flags/key down/up sequence recommended for
  -- CGEvents.
  schedule(state, interval, function()
    postKey(Keycodes.ctrl, true)
  end)
  schedule(state, interval * 2, function()
    postKey(arrow, true)
  end)
  schedule(state, interval * 3, function()
    postKey(arrow, false)
  end)
  schedule(state, interval * 4, function()
    postKey(Keycodes.ctrl, false)
  end)
end

function transport.start(window, direction, options, callback)
  options = options or {}

  if direction ~= -1 and direction ~= 1 then
    return nil, "direction must be -1 or 1"
  end

  local zoomOK, zoomRect = pcall(function()
    return window:zoomButtonRect()
  end)
  if not zoomOK then
    return nil, "could not locate the window title bar: " .. tostring(zoomRect)
  end
  if not zoomRect or zoomRect.w <= 0 or zoomRect.h <= 0 then
    return nil, "could not locate a draggable title-bar point"
  end

  local state = {
    callback = callback,
    cancelled = false,
    direction = direction,
    finished = false,
    keyInterval = math.max(0.01, tonumber(options.keyInterval) or 0.05),
    mouseDown = false,
    mouseOrigin = hs.mouse.absolutePosition(),
    timers = {}
  }

  function state:cancel()
    if self.cancelled or self.finished then return end
    self.cancelled = true
    stopTimers(self)
    pcall(releaseMouse, self)
    pcall(restoreMouse, self)
  end

  function state:fail(message)
    finish(self, false, message)
  end

  local titlebarOffset = tonumber(options.titlebarOffset) or 8
  local grabPoint = {
    x = zoomRect.x + zoomRect.w + titlebarOffset,
    y = zoomRect.y + (zoomRect.h / 2)
  }

  local startOK, startErr = pcall(function()
    postMouse(EventTypes.mouseMoved, grabPoint)
    postMouse(EventTypes.leftMouseDown, grabPoint)
    state.mouseDown = true

    local grabDelay = math.max(0.01, tonumber(options.grabDelay) or 0.15)
    local releaseDelay = math.max(
      grabDelay + (state.keyInterval * 5),
      tonumber(options.releaseDelay) or 1.8
    )

    schedule(state, grabDelay, function()
      postNativeSpaceSequence(state)
    end)
    schedule(state, releaseDelay, function()
      releaseMouse(state)
      restoreMouse(state)
      finish(state, true)
    end)
  end)

  if not startOK then
    state:cancel()
    return nil, "could not grab the window title bar: " .. tostring(startErr)
  end

  return state
end

return transport
