local path = debug.getinfo(1, "S").source:match("^@(.*/)")
local diagnostics = dofile(path .. "../Hammerspoon/TheseusWorkspace.spoon/establish_diagnostics.lua")
local assertions, now = 0, 100
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local trace = diagnostics.new(function() return now end)
local collect = trace:begin("collect", "com.openai.codex")
now = 103
collect({ success = true, seen = 2, eligible = 0 })
collect({ success = false })
equal(trace.data.events[1].durationSeconds, 3, "wall duration includes blocked work")
equal(trace.data.events[1].success, true, "completion is idempotent")
equal(trace.data.totals["collect:com.openai.codex"].calls, 1, "nested totals count once")
local wait = trace:begin("await-new-window", "com.openai.codex")
now = 109
trace:finish("active-space-changed")
wait({ success = true })
equal(trace.data.durationSeconds, 9, "total duration includes asynchronous wait")
equal(trace.data.events[2].reason, "active-space-changed", "cancelled spans retain reason")
equal(trace.data.events[2].durationSeconds, 6, "cancelled wait ends at operation stop")
equal(trace.data.totals["await-new-window:com.openai.codex"].durationSeconds, 6, "cancelled span contributes to totals")
now = 120; trace:finish()
equal(trace.data.durationSeconds, 9, "late callbacks cannot extend final duration")
trace = diagnostics.new(function() return now end)
for _ = 1, 530 do trace:begin("collect")() end
trace:finish()
equal(#trace.data.events, 512, "timeline has a fixed memory bound")
equal(trace.data.droppedEvents, 18, "omitted timeline events are explicit")
equal(trace.data.totals.collect.calls, 530, "totals survive timeline truncation")
local controller = {}
local first = { reason = "new-window-not-in-destination-space", diagnostics = trace.data }
diagnostics.retain(controller, first)
for _ = 1, 12 do diagnostics.retain(controller, { finished = true }) end
equal(controller.firstEstablishReport, first, "pin first report beyond history eviction")
equal(controller.firstEstablishReport.reason, "new-window-not-in-destination-space", "repeat cannot overwrite first failure")
equal(#controller.establishReports, 10, "retain only ten recent reports")
equal(controller.establishReports[1].attempt, 4, "history stays chronological")
equal(controller.lastEstablishReport.attempt, 13, "latest report remains compatible")
print(string.format("establish_diagnostics: %d assertions passed", assertions))
