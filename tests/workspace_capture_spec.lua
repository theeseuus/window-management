local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local fixture = dofile(testPath .. "workspace_panel_fixture.lua")
local previousHs, assertions = hs, 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, label)
  assertions = assertions + 1
  assert(math.abs(actual - expected) < .000001, label)
end

local f = fixture.new()
local view = f:open(true)
equal(view.shown, true, "show unified panel immediately")
equal(f:session().state, "capturing", "start capture in the existing panel")
equal(f.enumerations, 0, "paint disabled capture state before enumeration")
equal(view.source:find('id="name"', 1, true) ~= nil, true, "native form has naming field")
equal(view.source:find('placeholder="Name this layout" disabled', 1, true) ~= nil, true, "naming begins disabled")
equal(view.source:find('Positions are frozen', 1, true), nil, "omit redundant ready-state explanation")
equal(view.preferences.privateBrowsing, true, "no persistent web data")
equal(view.allowNewWindowsValue, false, "prevent extra webview windows")
equal(view.closeOnEscapeValue, false, "handle Escape within current view")
equal(view.behaviorValue, 2, "panel follows active Space without switching the user")
for _, url in ipairs({ "about:blank", { __luaSkinType = "NSURL", url = "about:blank" } }) do
  equal(view.policy("navigationAction", view, { request = { URL = url } }), true, "allow local HTML")
end
for _, url in ipairs({ "https://example.com", { url = "https://example.com" }, {} }) do
  equal(view.policy("navigationAction", view, { request = { URL = url } }), false, "deny remote and unknown navigation")
end
equal(view.policy("newWindow"), false, "deny new browser windows")
equal(view.policy("authenticationChallenge"), false, "deny authentication")
f:send("save", "Too early")
equal(f.writes, 0, "native controller rejects premature Save")
f:open(true)
f:send("capture")
equal(#f.views, 1, "repeated entry reuses the same panel")
equal(#f.timers, 1, "only one snapshot queued")
f:drain()
equal(f:session().state, "ready", "enable naming after snapshot completion")
equal(f.enumerations, 1, "enumerate application windows once")
equal(f.safari.reads, 1, "read Safari frame once")
equal(f.ghostty.reads, 1, "read Ghostty frame once")
equal(f.panel.reads, 0, "exclude manager before querying its frame")
equal(f.writes, 0, "ready snapshot has not been persisted")
equal(f:model().message, "2 windows captured", "concise completed-state wording")
equal(#f:model().capture.rectangles, 2, "one live preview rectangle per captured window")

f.ghostty.currentFrame.x, f.ghostty.currentFrame.w = 100, 400
f.screenFrame.w, f.spaceID = 3200, 902
f:send("save", "  Frozen Atlas  ")
local recipe = f:recipe("Frozen Atlas")
equal(recipe.name, "Frozen Atlas", "normalize saved name")
equal(#recipe.windows, 2, "never save the management window")
near(recipe.windows[2].frame.x, .5, "Save retains original Ghostty position")
near(recipe.windows[2].frame.w, .5, "Save retains original size and screen")
equal(f.enumerations, 1, "Save never enumerates again")
equal(f.ghostty.reads, 1, "Save never re-reads moved windows")
equal(f:session().state, "library", "successful Save returns to same list")
equal(f.workspace._workspaceUI.snapshot, nil, "release saved snapshot")
equal(f:model().selectedName, "Frozen Atlas", "select newly saved layout")
equal(f:model().clearQuery, true, "new saved layout is not hidden by an old search")
equal(view.deleted, nil, "Save keeps the same native window")
equal(#f.alerts, 0, "inline save does not add a redundant HUD")

f = fixture.new(); view = f:open(true)
f:send("cancel"); f:drain()
equal(f.enumerations, 0, "Cancel stops queued capture")
equal(f.writes, 0, "Cancel does not persist")
equal(f:session().state, "library", "Cancel returns to the same list")
equal(view.deleted, nil, "Cancel does not create or close another window")
f:capture()
equal(f:session().state, "ready", "capture again after Cancel")
f:send("save", "   ")
equal(f:session().state, "ready", "invalid name permits correction")
equal(f.writes, 0, "invalid name never saves")
f:send("cancel")
equal(f.workspace._workspaceUI.snapshot, nil, "Cancel discards ready snapshot")

f = fixture.new(); f:open(true); f:drain(); f.saveError = true
f:send("save", "Retry")
equal(f:session().state, "ready", "settings failure permits retry")
equal(f.writes, 0, "failed write is not success")
f.saveError = false; f.ghostty.currentFrame.x = 100
f:send("save", "Retry")
near(f:recipe("Retry").windows[2].frame.x, .5, "retry still uses frozen position")
equal(f.enumerations, 1, "retry never recaptures")

f = fixture.new(); f:seed({ "Existing" }); local original = f:recipe("Existing")
f:open(true); f:drain(); f:send("save", "Existing")
equal(f:session().state, "confirm-replace", "duplicate name needs inline confirmation")
equal(f:recipe("Existing"), original, "unconfirmed replacement preserves recipe")
f:send("save", "Existing")
equal(f.writes, 0, "repeated Save cannot bypass confirmation")
f:send("cancel")
equal(f:session().state, "ready", "replacement Cancel returns to naming")
f:send("save", "Existing"); f.ghostty.currentFrame.x = 1200; f:send("confirm-replace")
near(f:recipe("Existing").windows[2].frame.x, .5, "confirmed replacement uses frozen geometry")
equal(f.enumerations, 1, "confirmation never captures again")

f = fixture.new(); f:seed({ "Existing" }); f:open(true); f:drain(); f:send("save", "Existing")
f:recipe("Existing").windows[1].frame.x = .1
f:send("confirm-replace")
equal(f.writes, 0, "changed saved recipe invalidates replacement confirmation")
equal(f:session().state, "ready", "stale replacement returns to naming")
near(f:recipe("Existing").windows[1].frame.x, .1, "preserve updated saved recipe")

f = fixture.new(); f:open(true); f:drain()
local sibling = f.workspace:captureCurrentWorkspace("Sibling", { silent = true })
equal(#sibling.windows, 2, "direct capture also excludes the open panel")
f:send("save", "Panel")
equal(f:recipe("Sibling").name, "Sibling", "preserve catalog changes while naming")
equal(f:recipe("Panel").name, "Panel", "save into latest catalog")

for _, scenario in ipairs({ "empty", "Space-before", "Space-during", "app-enumeration", "Space-enumeration" }) do
  f = fixture.new(); f:open(true)
  if scenario == "empty" then f.windowIDs = { 99 }
  elseif scenario == "Space-before" then f.spaceID = 902
  elseif scenario == "Space-during" then f.afterEnumeration = function() f.spaceID = 902 end
  elseif scenario == "app-enumeration" then f.enumerationError = true
  else f.spaceEnumerationError = true end
  f:drain()
  equal(f:session().state, "failed", scenario .. " fails closed")
  f:send("save", "Must not save")
  equal(f.writes, 0, scenario .. " cannot persist an invalid snapshot")
  f:send("cancel")
  equal(f:session().state, "library", scenario .. " can return to library")
end

f = fixture.new(); view = f:open(true); f.workspace:stop(); f:drain()
equal(f.enumerations, 0, "Spoon stop cancels queued capture")
equal(f:session(), nil, "Spoon stop releases session")
equal(view.deleted, true, "Spoon stop destroys native window")
f = fixture.new(); view = f:open(true); view.closingCallback("closing", view); f:drain()
equal(f.enumerations, 0, "native close cancels capture")
equal(f:session(), nil, "native close releases session")
f = fixture.new(); f.spaceType = "fullscreen"; f:open()
equal(#f.views, 0, "reject incompatible Space before opening")
equal(f.enumerations, 0, "never scan incompatible Space")

f = fixture.new()
local root = testPath:match("^(.*)/tests/$")
local controller = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/panel_controller.lua")
local failedCapture = controller.new({
  context = function() return { screenFrame = f.screenFrame } end,
  catalog = function() return { recipes = {} } end,
  busy = function() return nil end,
  snapshot = function() error("unexpected accessibility error") end,
  reason = tostring,
  alert = function() error("capture should show its error inline") end,
})
failedCapture:show(true)
f.views[1].content.callback({ body = { action = "ready" } })
f:drain()
equal(failedCapture.session.state, "failed", "unexpected snapshot exception cannot leave capture stuck")
equal(failedCapture.session.model.error:find("unexpected accessibility error", 1, true) ~= nil, true, "show exception inline")
equal(f.writes, 0, "unexpected snapshot exception cannot save")
failedCapture:close()
equal(failedCapture.session, nil, "failed capture still closes cleanly")

hs = previousHs
print(string.format("workspace_capture_spec: %d assertions passed", assertions))
