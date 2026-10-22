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
    if state.positionSetter then state.positionSetter(point)
    elseif not state.ignoreStaged then
      state.frame.x, state.frame.y = point.x, point.y
    end
    return self
  end
  function state:start(duration)
    self.job = restore.place(self.window, target, {
      animationDuration = duration or 0,
      initialFrame = self.initialFrame,
      newlyCreated = self.newlyCreated,
      placementPolicy = self.placementPolicy,
      scheduleAfter = self.schedule,
      guard = function() return self.eligible, "window-no-longer-eligible" end,
    }, function(success, reason, actual, metrics)
      self.metrics = metrics
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

-- Newly created windows may accept a write and then restore startup geometry.
-- They need bounded recovery and consecutive readbacks, not another creation.
local startup = fixture()
startup.newlyCreated, startup.ignoreStaged = true, true
startup.fullSetter = function(frame)
  if startup.now >= 2.1 then startup.frame = copy(frame) end
end
startup:start(); startup:drain()
equal(startup.success, true, "recover a newly created window after its startup geometry settles")
equal(startup.fullRequests > 2, true, "recover within the same placement job")
equal(startup.completions, 1, "startup recovery completes once")

local transient = fixture()
transient.newlyCreated = true
transient.fullSetter = function(frame)
  transient.frame = copy(frame)
  if transient.fullRequests == 1 then
    transient.schedule(0.4, function() transient.frame = { x = 22, y = 52, w = 400, h = 500 } end)
  end
end
transient:start(); transient:drain()
equal(transient.success, true, "recover startup snapback after the first matching read")
equal(transient.fullRequests, 2, "do not report transient first match as settled")
equal(transient.now >= 1.0, true, "require consecutive matching checks after recovery")

local freshUnchanged = fixture()
freshUnchanged.newlyCreated = true
freshUnchanged.frame, freshUnchanged.initialFrame = copy(target), copy(target)
freshUnchanged:start(); freshUnchanged:drain()
equal(freshUnchanged.success, true, "verify a newly created window already at target")
equal(freshUnchanged.fullRequests, 0, "stable new window needs no writes")
equal(freshUnchanged.now, 0.5, "two readbacks prove new-window stability")

local startupIgnored = fixture()
startupIgnored.newlyCreated, startupIgnored.ignoreStaged = true, true
startupIgnored.fullSetter = function() end
startupIgnored:start(); startupIgnored:drain()
equal(startupIgnored.success, false, "new-window startup recovery is still bounded")
equal(startupIgnored.reason, "frame-not-restored", "truthful failure after startup recovery")
equal(startupIgnored.fullRequests, 6, "at most three two-request recovery cycles")
equal(startupIgnored.positionRequests, 3, "at most three staged moves")
equal(startupIgnored.completions, 1, "exhausted new-window recovery completes once")

local startupLost = fixture()
startupLost.newlyCreated, startupLost.ignoreStaged = true, true
startupLost.fullSetter = function() end
startupLost.schedule(1.1, function() startupLost.eligible = false end)
startupLost:start(); startupLost:drain()
equal(startupLost.reason, "window-no-longer-eligible", "extended recovery retains eligibility guard")
equal(startupLost.fullRequests, 2, "no extended writes after losing eligibility")

local startupCancelled = fixture()
startupCancelled.newlyCreated, startupCancelled.ignoreStaged = true, true
startupCancelled.fullSetter = function() end
startupCancelled.schedule(1.1, function() startupCancelled.job:cancel() end)
startupCancelled:start(); startupCancelled:drain()
equal(startupCancelled.reason, "restore-cancelled", "cancel during extended startup recovery")
equal(startupCancelled.fullRequests, 2, "cancelled recovery cannot issue delayed writes")
equal(startupCancelled.completions, 1, "extended cancellation completes once")

-- A reviewed app can avoid repeated resizing only when a fresh read confirms
-- the desired size. Every other placement keeps the original recovery path.
local function positionedFixture()
  local state = fixture()
  state.newlyCreated, state.placementPolicy = true, "position-only-when-sized"
  state.frame.w, state.frame.h = target.w, target.h
  return state
end

local sameSize = positionedFixture()
sameSize:start(); sameSize:drain()
equal(sameSize.success, true, "position a same-size new window")
equal(sameSize.fullRequests, 0, "same-size policy avoids full-frame writes")
equal(sameSize.sizeRequests, 0, "same-size policy never resizes")
equal(sameSize.positionRequests, 1, "successful position is requested once")
equal(sameSize.metrics.positionRequests, 1, "retain position request metric")
equal(sameSize.metrics.fullFrameRequests, 0, "retain zero full-frame metric")
equal(sameSize.metrics.sizeRequests, 0, "retain zero resize metric")
equal(sameSize.metrics.frameChecks, 3, "fresh frame plus two matching readbacks")
equal(sameSize.now, 0.5, "quick position waits only for matching readbacks")

local delayedPosition = positionedFixture()
delayedPosition.positionSetter = function(point)
  if delayedPosition.positionRequests >= 5 then
    delayedPosition.frame.x, delayedPosition.frame.y = point.x, point.y
  end
end
delayedPosition:start(); delayedPosition:drain()
equal(delayedPosition.success, true, "bounded position retries handle initially ignored moves")
equal(delayedPosition.positionRequests, 5, "stop requests at first matching frame")
equal(delayedPosition.fullRequests, 0, "delayed position needs no combined frame writes")
equal(delayedPosition.sizeRequests, 0, "delayed position needs no resizes")
equal(delayedPosition.now, 1.5, "verify delayed position twice")

local transientPosition = positionedFixture()
transientPosition.positionSetter = function(point)
  transientPosition.frame.x, transientPosition.frame.y = point.x, point.y
  if transientPosition.positionRequests == 1 then
    transientPosition.schedule(0.4, function() transientPosition.frame.x = 20 end)
  end
end
transientPosition:start(); transientPosition:drain()
equal(transientPosition.success, true, "recover a position that reverts after first match")
equal(transientPosition.positionRequests, 2, "first matching read causes no redundant request")
equal(transientPosition.fullRequests, 0, "transient position can recover without resizing")
equal(transientPosition.now, 1, "wait for consecutive matches after drift")

local existingSized = positionedFixture()
existingSized.newlyCreated = false
existingSized:start(); existingSized:drain()
equal(existingSized.fullRequests, 1, "existing windows retain ordinary full-frame placement")
equal(existingSized.positionRequests, 0, "existing windows ignore startup-only policy")
equal(existingSized.now, 0.25, "existing-window timing is unchanged")

local unknownPolicy = positionedFixture()
unknownPolicy.placementPolicy = "unreviewed"
unknownPolicy:start(); unknownPolicy:drain()
equal(unknownPolicy.fullRequests, 1, "unknown policy retains original placement")
equal(unknownPolicy.positionRequests, 0, "unknown policy cannot select position-only path")

local differentSize = positionedFixture()
differentSize.frame.w = target.w - 100
differentSize:start(); differentSize:drain()
equal(differentSize.success, true, "different size uses original placement")
equal(differentSize.fullRequests, 1, "different size enters full-frame path immediately")
equal(differentSize.positionRequests, 0, "different size skips speculative position requests")
equal(differentSize.sizeRequests, 0, "different size introduces no new resize phase")

local sizeReverted = positionedFixture()
sizeReverted.positionSetter = function(point)
  sizeReverted.frame.x, sizeReverted.frame.y = point.x, point.y
  sizeReverted.frame.w = target.w - 100
end
sizeReverted:start(); sizeReverted:drain()
equal(sizeReverted.success, true, "size drift enters original full-frame recovery")
equal(sizeReverted.positionRequests, 1, "stop position-only writes when size falls away")
equal(sizeReverted.fullRequests, 1, "recover size drift with original full-frame path")

local boundedMoves = positionedFixture()
boundedMoves.positionSetter = function() end
boundedMoves:start(); boundedMoves:drain()
equal(boundedMoves.success, true, "ignored moves can recover with original full-frame path")
equal(boundedMoves.positionRequests, 8, "position-only requests have an eight-request cap")
equal(boundedMoves.fullRequests, 1, "fallback begins after position-only cap")
equal(boundedMoves.metrics.positionRequests, 8, "metrics retain all ignored move attempts")

local allIgnored = positionedFixture()
allIgnored.ignoreStaged = true
allIgnored.fullSetter = function() end
allIgnored:start(); allIgnored:drain()
equal(allIgnored.success, false, "ignored moves and original recovery fail truthfully")
equal(allIgnored.reason, "frame-not-restored", "exhausted fallback has original failure reason")
equal(allIgnored.positionRequests, 11, "eight new moves plus three original staged moves")
equal(allIgnored.fullRequests, 6, "original full-frame recovery retains its cap")
equal(allIgnored.sizeRequests, 3, "original resize fallback retains its cap")
equal(allIgnored.completions, 1, "exhausted position-only job completes once")

local freshRead = positionedFixture()
freshRead.initialFrame = copy(target)
freshRead:start()
equal(freshRead.positionRequests, 1, "fresh frame overrides stale initial target match")
freshRead:drain()
equal(freshRead.success, true, "fresh-read placement verifies")

local alreadyPlaced = positionedFixture()
alreadyPlaced.frame, alreadyPlaced.initialFrame = copy(target), copy(target)
alreadyPlaced:start(); alreadyPlaced:drain()
equal(alreadyPlaced.success, true, "stable target still verifies twice")
equal(alreadyPlaced.positionRequests, 0, "already placed new window needs no move")
equal(alreadyPlaced.fullRequests, 0, "already placed new window needs no full-frame write")

local laterDrift = positionedFixture()
laterDrift.frame, laterDrift.initialFrame = copy(target), copy(target)
laterDrift.schedule(0.1, function() laterDrift.frame.x = 20 end)
laterDrift:start(); laterDrift:drain()
equal(laterDrift.success, true, "initially correct frame can drift into position-only recovery")
equal(laterDrift.positionRequests, 1, "detected initial drift stays on preferred path")
equal(laterDrift.fullRequests, 0, "initial drift avoids combined writes")

local lostBefore = positionedFixture()
lostBefore.eligible = false
lostBefore:start()
equal(lostBefore.metrics.frameChecks, 0, "guard before fresh frame read")
equal(lostBefore.positionRequests, 0, "initial eligibility loss causes no move")
equal(lostBefore.reason, "window-no-longer-eligible", "initial guard failure propagates")

local lostDuring = positionedFixture()
lostDuring:start(); lostDuring.eligible = false; lostDuring:drain()
equal(lostDuring.positionRequests, 1, "eligibility loss prevents pending move retry")
equal(lostDuring.fullRequests, 0, "eligibility loss prevents fallback")
equal(lostDuring.completions, 1, "eligibility loss completes once")

local cancelledMove = positionedFixture()
cancelledMove:start()
local pendingMoveCheck = cancelledMove.queue[1]
cancelledMove.job:cancel(); cancelledMove.job:cancel()
pendingMoveCheck.callback(); cancelledMove:drain()
equal(cancelledMove.reason, "restore-cancelled", "cancel preferred position job")
equal(cancelledMove.positionRequests, 1, "late callback cannot retry cancelled move")
equal(cancelledMove.metrics.frameChecks, 1, "late callback cannot read cancelled window")
equal(cancelledMove.completions, 1, "cancel completes preferred job once")

local positionReadError = positionedFixture()
positionReadError.readError = true
positionReadError:start()
equal(positionReadError.reason, "could-not-read-restored-frame", "fresh frame read failure stops placement")
equal(positionReadError.positionRequests, 0, "unreadable window receives no move")

local positionScheduleError = positionedFixture()
positionScheduleError.schedule = function() return nil end
positionScheduleError:start()
equal(positionScheduleError.reason, "could-not-schedule-frame-check", "preferred scheduler failure cannot hang")
equal(positionScheduleError.completions, 1, "preferred scheduler failure completes once")

local moveError = positionedFixture()
moveError.positionSetter = function() error("move rejected") end
moveError:start()
equal(moveError.success, false, "position setter exception fails placement")
equal(moveError.positionRequests, 1, "setter exception counts the attempted move")
equal(moveError.fullRequests, 0, "setter exception cannot silently start fallback")

print(string.format("frame_restore_spec: %d assertions passed", assertions))
