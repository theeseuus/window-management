local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local restore = dofile(repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/frame_restore.lua")
local assertions = 0

local function equal(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local target = { x = 100, y = 50, w = 800, h = 1000 }
local function copy(frame)
  return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function fixture()
  local state = {
    frame = { x = 0, y = 0, w = 400, h = 500 },
    queue = {}, now = 0, eligible = true,
    fullRequests = 0, sizeRequests = 0, positionRequests = 0, completions = 0,
  }
  function state.schedule(delay, callback)
    local timer = { time = state.now + delay, callback = callback }
    function timer:stop() self.stopped = true end
    table.insert(state.queue, timer)
    return timer
  end
  function state:drain()
    local steps = 0
    while #self.queue > 0 do
      steps = steps + 1
      if steps > 30 then error("frame restoration must be bounded") end
      table.sort(self.queue, function(left, right) return left.time < right.time end)
      local timer = table.remove(self.queue, 1)
      self.now = timer.time
      if not timer.stopped then timer.callback() end
    end
  end
  state.window = {}
  function state.window:frame()
    if state.readError then error("frame unavailable") end
    if state.invalidRead then return 42 end
    return copy(state.frame)
  end
  function state.window:setFrameInScreenBounds(frame, duration)
    state.fullRequests = state.fullRequests + 1
    state.duration = duration
    if state.requestError then error("request rejected") end
    if state.fullSetter then state.fullSetter(frame)
    else state.frame = copy(frame) end
    return self
  end
  function state.window:setSize(size)
    state.sizeRequests = state.sizeRequests + 1
    if not state.ignoreStaged then
      state.frame.w, state.frame.h = size.w, size.h
    end
    return self
  end
  function state.window:setTopLeft(point)
    state.positionRequests = state.positionRequests + 1
    if not state.ignoreStaged then
      state.frame.x, state.frame.y = point.x, point.y
    end
    return self
  end
  function state:start(duration)
    self.job = restore.place(self.window, target, {
      animationDuration = duration or 0,
      initialFrame = self.initialFrame,
      scheduleAfter = self.schedule,
      guard = function() return self.eligible, "window-no-longer-eligible" end,
    }, function(success, reason, actual)
      self.completions = self.completions + 1
      self.success, self.reason, self.actual = success, reason, actual
    end)
  end
  return state
end

local direct = fixture()
direct:start()
equal(direct.completions, 0, "do not count an accepted request before settling")
equal(direct.job.finished, false, "accepted request still awaits verification")
direct:drain()
equal(direct.success, true, "verify ordinary placement")
equal(direct.completions, 1, "complete ordinary placement once")
equal(direct.fullRequests, 1, "do not retry a successful placement")
equal(direct.sizeRequests, 0, "do not use fallback unnecessarily")
equal(direct.actual.x, target.x, "read back the actual frame")
equal(direct.now, 0.25, "allow a zero-duration request to settle")

local unchanged = fixture()
unchanged.frame, unchanged.initialFrame = copy(target), copy(target)
unchanged:start()
equal(unchanged.completions, 0, "already placed windows still require verification")
equal(unchanged.fullRequests, 0, "do not move an already placed window")
unchanged:drain()
equal(unchanged.success, true, "verify an unchanged layout")
equal(unchanged.fullRequests, 0, "unchanged layout needs no frame writes")

local drifted = fixture()
drifted.initialFrame = copy(target)
drifted:start()
drifted:drain()
equal(drifted.success, true, "recover drift since initial matching")
equal(drifted.fullRequests, 1, "stale matching cannot silently skip placement")

local retry = fixture()
retry.fullSetter = function(frame)
  if retry.fullRequests > 1 then retry.frame = copy(frame) end
end
retry:start()
retry:drain()
equal(retry.success, true, "retry an initially ignored request")
equal(retry.fullRequests, 2, "bound ordinary frame retries")
equal(retry.sizeRequests, 0, "successful retry needs no staged fallback")
equal(retry.completions, 1, "complete a retry once")

local staged = fixture()
staged.fullSetter = function() end
staged:start()
staged:drain()
equal(staged.success, true, "staged resize then move can recover a quiet no-op")
equal(staged.fullRequests, 2, "attempt full frames before staging")
equal(staged.sizeRequests, 1, "request the saved size once")
equal(staged.positionRequests, 1, "request the saved position once")
equal(staged.frame.x, target.x, "staged position reaches target")
equal(staged.frame.w, target.w, "staged size reaches target")
equal(staged.now, 1.0, "staged requests are separated by settling intervals")

local ignored = fixture()
ignored.fullSetter = function() end
ignored.ignoreStaged = true
ignored:start()
ignored:drain()
equal(ignored.success, false, "never report a quiet no-op as success")
equal(ignored.reason, "frame-not-restored", "quiet no-op has a specific failure")
equal(ignored.fullRequests, 2, "quiet no-op full retries are bounded")
equal(ignored.sizeRequests, 1, "quiet no-op fallback size is bounded")
equal(ignored.positionRequests, 1, "quiet no-op fallback move is bounded")
equal(ignored.completions, 1, "quiet no-op completes exactly once")
equal(ignored.actual.x, 0, "failure records the observed frame")

local delayed = fixture()
delayed.fullSetter = function(frame)
  delayed.schedule(0.1, function() delayed.frame = copy(frame) end)
end
delayed:start()
delayed:drain()
equal(delayed.success, true, "accept delayed application placement")
equal(delayed.fullRequests, 1, "do not retry before the settling interval")

local reverted = fixture()
reverted.fullSetter = function(frame)
  reverted.frame = copy(frame)
  reverted.schedule(0.1, function()
    reverted.frame = { x = 0, y = 0, w = 400, h = 500 }
  end)
end
reverted:start()
reverted:drain()
equal(reverted.success, true, "recover a frame reverted after the initial API call")
equal(reverted.fullRequests, 2, "detect post-call reversion before claiming success")
equal(reverted.positionRequests, 1, "use staged placement after repeated reversion")

local rounding = fixture()
rounding.fullSetter = function(frame)
  rounding.frame = copy(frame)
  rounding.frame.x = rounding.frame.x - 1
  rounding.frame.w = rounding.frame.w + 2
end
rounding:start()
rounding:drain()
equal(rounding.success, true, "allow two-point application or pixel rounding")
equal(rounding.fullRequests, 1, "rounding does not cause needless retries")

local animated = fixture()
animated:start(0.5)
animated:drain()
equal(animated.success, true, "verify after the configured animation")
equal(animated.duration, 0.5, "preserve the configured animation duration")
equal(animated.now, 0.6, "wait beyond the animation before reading back")

local requestError = fixture()
requestError.requestError = true
requestError:start()
equal(requestError.success, false, "request exception is a failure")
equal(requestError.completions, 1, "request exception completes once")
equal(#requestError.queue, 0, "request exception leaves no timers")

local readError = fixture()
readError.readError = true
readError:start()
readError:drain()
equal(readError.success, false, "frame-read exception is a failure")
equal(readError.reason, "could-not-read-restored-frame", "frame-read failure reason")

local invalid = fixture()
invalid.invalidRead = true
invalid:start()
invalid:drain()
equal(invalid.success, false, "invalid frame reads never prove placement")
equal(invalid.completions, 1, "invalid frame reads remain bounded")

local lost = fixture()
lost.fullSetter = function() end
lost:start()
lost.eligible = false
lost:drain()
equal(lost.success, false, "stop after window eligibility changes")
equal(lost.reason, "window-no-longer-eligible", "eligibility failure reason")
equal(lost.fullRequests, 1, "do not retry an ineligible window")
equal(lost.sizeRequests, 0, "do not stage an ineligible window")

local absent = fixture()
absent.eligible = false
absent:start()
equal(absent.success, false, "check eligibility before the first request")
equal(absent.fullRequests, 0, "leave an initially ineligible window untouched")

local cancelled = fixture()
cancelled:start()
cancelled.job:cancel()
cancelled.job:cancel()
cancelled:drain()
equal(cancelled.success, false, "cancel pending verification")
equal(cancelled.reason, "restore-cancelled", "cancellation failure reason")
equal(cancelled.completions, 1, "cancellation completes only once")
equal(cancelled.fullRequests, 1, "cancelled timers cannot retry")

local scheduleError = fixture()
scheduleError.schedule = function() error("scheduler unavailable") end
scheduleError:start()
equal(scheduleError.success, false, "scheduler exception does not hang the job")
equal(scheduleError.reason, "could-not-schedule-frame-check", "scheduler failure reason")
equal(scheduleError.job.finished, true, "scheduler failure finishes the job")

print(string.format("frame_restore_spec: %d assertions passed", assertions))
