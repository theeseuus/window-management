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
  local job = { finished = false, metrics = {
    fullFrameRequests = 0, sizeRequests = 0, positionRequests = 0, frameChecks = 0,
  } }
  local duration = options.animationDuration
  if not finite(duration) or duration < 0 then duration = 0 end
  local delay = math.max(0.25, duration + 0.1)
  -- A newly created native window can accept a frame and subsequently restore
  -- its startup geometry. Existing windows keep the original short retry path.
  local newlyCreated = options.newlyCreated == true
  local cycleLimit = newlyCreated and 3 or 1
  local cycle, fullAttempts, matchingChecks = 1, 0, 0

  local function finish(success, reason, actual)
    if job.finished then return end
    job.finished = true
    if job.timer then
      pcall(function() job.timer:stop() end)
      job.timer = nil
    end
    complete(success, reason, actual, job.metrics)
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

  local function request(callback, metric)
    if not permitted() then return false end
    matchingChecks = 0
    job.metrics[metric] = job.metrics[metric] + 1
    local ok, err = pcall(callback)
    if not ok then
      finish(false, tostring(err))
      return false
    end
    return true
  end

  local function readFrame()
    job.metrics.frameChecks = job.metrics.frameChecks + 1
    return pcall(function() return window:frame() end)
  end

  local verify, fullFrame

  local function stagedFrame()
    -- Let the resize settle before moving. This avoids an application's
    -- resize animation cancelling an immediately following position request.
    if not request(function() window:setSize({ w = target.w, h = target.h }) end, "sizeRequests") then
      return
    end
    later(function()
      if request(function() window:setTopLeft({ x = target.x, y = target.y }) end, "positionRequests") then
        later(function() verify(true) end)
      end
    end)
  end

  verify = function(finalAttempt)
    if not permitted() then return end
    local ok, actual = readFrame()
    if not ok then
      finish(false, "could-not-read-restored-frame")
    elseif matches(actual, target, 2) then
      matchingChecks = matchingChecks + 1
      if not newlyCreated or matchingChecks >= 2 then
        finish(true, nil, actual)
      else
        later(function() verify(finalAttempt) end)
      end
    else
      matchingChecks = 0
      if finalAttempt then
        if cycle < cycleLimit then
          cycle, fullAttempts = cycle + 1, 0
          later(fullFrame)
        else finish(false, "frame-not-restored", actual) end
      elseif fullAttempts < 2 then
        fullFrame()
      else
        stagedFrame()
      end
    end
  end

  fullFrame = function()
    fullAttempts = fullAttempts + 1
    if request(function() window:setFrameInScreenBounds(target, duration) end, "fullFrameRequests") then
      later(function() verify(false) end)
    end
  end

  local function positionOnlyWhenSized()
    -- Avoid redundant resizes when a new window already has its saved size.
    -- Verify each position request; preserve the original recovery if size
    -- differs, changes, or the bounded position-only requests are ignored.
    local moveAttempts = 0
    local verifyPosition, movePosition
    local function sizeMatches(actual)
      return type(actual) == "table" and finite(actual.w) and finite(actual.h)
        and math.abs(actual.w - target.w) <= 2 and math.abs(actual.h - target.h) <= 2
    end
    movePosition = function()
      moveAttempts = moveAttempts + 1
      if request(function() window:setTopLeft({ x = target.x, y = target.y }) end, "positionRequests") then
        later(verifyPosition)
      end
    end
    verifyPosition = function()
      if not permitted() then return end
      local ok, actual = readFrame()
      if not ok then
        finish(false, "could-not-read-restored-frame")
      elseif not sizeMatches(actual) then
        fullFrame()
      elseif matches(actual, target, 2) then
        matchingChecks = matchingChecks + 1
        if matchingChecks >= 2 then finish(true, nil, actual)
        else later(verifyPosition) end
      else
        matchingChecks = 0
        if moveAttempts < 8 then movePosition()
        else fullFrame() end
      end
    end

    if not permitted() then return end
    local ok, actual = readFrame()
    if not ok then
      finish(false, "could-not-read-restored-frame")
    elseif not sizeMatches(actual) then
      fullFrame()
    elseif matches(actual, target, 2) then
      later(verifyPosition)
    else
      movePosition()
    end
  end

  if newlyCreated and options.placementPolicy == "position-only-when-sized" then
    positionOnlyWhenSized()
  -- Matching already observed this frame. Avoid a redundant resize/move when
  -- reapplying a layout, but still verify later and recover any intervening drift.
  elseif matches(options.initialFrame, target, 2) then
    if permitted() then later(function() verify(false) end) end
  else
    fullFrame()
  end
  return job
end

return restore
