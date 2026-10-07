-- Bounded, asynchronous placement verification. A successful API call is
-- not evidence that macOS or the application accepted the requested frame.
local restore = {}

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function matches(actual, target, tolerance)
  if type(actual) ~= "table" then return false end
  for _, key in ipairs({ "x", "y", "w", "h" }) do
    if not finite(actual[key]) or math.abs(actual[key] - target[key]) > tolerance then
      return false
    end
  end
  return true
end

function restore.place(window, target, options, complete)
  local job = { finished = false }
  local duration = options.animationDuration
  if not finite(duration) or duration < 0 then duration = 0 end
  local delay = math.max(0.25, duration + 0.1)
  local fullAttempts = 0

  local function finish(success, reason, actual)
    if job.finished then return end
    job.finished = true
    if job.timer then
      pcall(function() job.timer:stop() end)
      job.timer = nil
    end
    complete(success, reason, actual)
  end

  function job:cancel()
    finish(false, "restore-cancelled")
  end

  local function permitted()
    if job.finished then return false end
    local ok, allowed, reason = pcall(options.guard)
    if not ok or not allowed then
      finish(false, ok and (reason or "window-no-longer-eligible") or tostring(allowed))
      return false
    end
    return true
  end

  local function later(callback)
    local ok, timer = pcall(options.scheduleAfter, delay, function()
      job.timer = nil
      if not job.finished then callback() end
    end)
    if not ok or not timer then
      finish(false, "could-not-schedule-frame-check")
    else
      job.timer = timer
    end
  end

  local function request(callback)
    if not permitted() then return false end
    local ok, err = pcall(callback)
    if not ok then
      finish(false, tostring(err))
      return false
    end
    return true
  end

  local verify, fullFrame

  local function stagedFrame()
    -- Let the resize settle before moving. This avoids an application's
    -- resize animation cancelling an immediately following position request.
    if not request(function() window:setSize({ w = target.w, h = target.h }) end) then
      return
    end
    later(function()
      if request(function() window:setTopLeft({ x = target.x, y = target.y }) end) then
        later(function() verify(true) end)
      end
    end)
  end

  verify = function(finalAttempt)
    if not permitted() then return end
    local ok, actual = pcall(function() return window:frame() end)
    if not ok then
      finish(false, "could-not-read-restored-frame")
    elseif matches(actual, target, 2) then
      finish(true, nil, actual)
    elseif finalAttempt then
      finish(false, "frame-not-restored", actual)
    elseif fullAttempts < 2 then
      fullFrame()
    else
      stagedFrame()
    end
  end

  fullFrame = function()
    fullAttempts = fullAttempts + 1
    if request(function() window:setFrameInScreenBounds(target, duration) end) then
      later(function() verify(false) end)
    end
  end

  -- Matching already observed this frame. Avoid a redundant resize/move when
  -- reapplying a layout, but still verify later and recover any intervening drift.
  if matches(options.initialFrame, target, 2) then
    if permitted() then later(function() verify(false) end) end
  else
    fullFrame()
  end
  return job
end

return restore
