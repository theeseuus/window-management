-- Bounded, memory-only measurements of existing work; never polls the desktop.
local diagnostics = {}
function diagnostics.new(clock)
  clock = clock or function()
    if hs and hs.timer and hs.timer.absoluteTime then return hs.timer.absoluteTime() / 1e9 end
    return os.clock() -- deterministic test environments may inject their own clock
  end
  local started = clock()
  local trace = { data = { startedAtUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    events = {}, totals = {}, droppedEvents = 0 }, open = {} }
  function trace:begin(stage, bundleID)
    local at = clock()
    local event = { stage = stage, bundleID = bundleID, offsetSeconds = at - started }
    if #self.data.events < 512 then table.insert(self.data.events, event)
    else self.data.droppedEvents = self.data.droppedEvents + 1 end
    local function closed(fields)
      if not self.open[event] then return end
      self.open[event] = nil
      event.durationSeconds = math.max(0, clock() - at)
      for key, value in pairs(fields or {}) do event[key] = value end
      local key = stage .. (bundleID and (":" .. bundleID) or "")
      local total = self.data.totals[key] or { calls = 0, durationSeconds = 0 }
      total.calls = total.calls + 1
      total.durationSeconds = total.durationSeconds + event.durationSeconds
      self.data.totals[key] = total
    end
    self.open[event] = closed
    return closed
  end
  function trace:finish(reason)
    if self.data.durationSeconds then return end
    local unfinished = {}
    for _, closed in pairs(self.open) do table.insert(unfinished, closed) end
    -- Outstanding asynchronous work is cut short by the existing cancellation path.
    for _, closed in ipairs(unfinished) do closed({ reason = reason or "operation-finished" }) end
    self.data.durationSeconds = math.max(0, clock() - started)
  end
  return trace
end
function diagnostics.retain(controller, report)
  controller.establishReports = controller.establishReports or {}
  controller._establishSequence = (controller._establishSequence or 0) + 1
  report.attempt = controller._establishSequence
  controller.firstEstablishReport = controller.firstEstablishReport or report
  controller.lastEstablishReport = report
  table.insert(controller.establishReports, report)
  if #controller.establishReports > 10 then table.remove(controller.establishReports, 1) end
end
return diagnostics
