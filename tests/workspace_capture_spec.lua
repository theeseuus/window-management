local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local assertions = 0
local previousHs = hs

local function equal(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local function near(actual, expected, label)
  assertions = assertions + 1
  if math.abs(actual - expected) > 0.000001 then
    error(string.format("%s: expected %.8f, got %.8f", label, expected, actual), 2)
  end
end

local function fixture()
  local f = {
    settings = {}, writes = 0, enumerations = 0, views = {}, timers = {}, alerts = {},
    spaceID = 901, windowIDs = { 11, 21, 99 }, confirmation = "Cancel",
    screenFrame = { x = 100, y = 50, w = 1600, h = 1000 },
  }
  local screen = {}
  function screen:id() return 1 end
  function screen:frame() return f.screenFrame end
  local function window(id, bundleID, title, frame)
    local app = {}
    function app:bundleID() return bundleID end
    function app:title() return title end
    local w = { currentFrame = frame, reads = 0 }
    function w:id() return id end
    function w:isStandard() return true end
    function w:isVisible() return true end
    function w:isMinimized() return false end
    function w:isFullScreen() return false end
    function w:screen() return screen end
    function w:application() return app end
    function w:frame() self.reads = self.reads + 1; return self.currentFrame end
    function w:title() error("capture must never query window titles") end
    return w
  end
  f.safari = window(11, "com.apple.Safari", "Safari", { x = 100, y = 50, w = 800, h = 1000 })
  f.ghostty = window(21, "com.mitchellh.ghostty", "Ghostty", { x = 900, y = 50, w = 800, h = 1000 })
  f.panel = window(99, "org.hammerspoon.Hammerspoon", "Hammerspoon", { x = 500, y = 300, w = 480, h = 330 })
  local lastEncoded
  hs = {
    screen = { mainScreen = function() return screen end },
    window = {
      focusedWindow = function() return f.safari end,
      get = function() error("collector must not perform per-ID application scans") end,
      allWindows = function()
        f.enumerations = f.enumerations + 1
        if f.enumerationError then error("accessibility enumeration unavailable") end
        if f.afterEnumeration then f.afterEnumeration() end
        return { f.safari, f.ghostty, f.panel }
      end,
    },
    spaces = {
      activeSpaceOnScreen = function() return f.spaceID end,
      spaceType = function() return f.spaceType or "user" end,
      windowsForSpace = function()
        if f.spaceEnumerationError then return nil, "Space enumeration unavailable" end
        return f.windowIDs
      end,
      windowSpaces = function() return { 901 } end,
    },
    settings = {
      get = function(key) return f.settings[key] end,
      set = function(key, value)
        if f.saveError then error("settings write unavailable") end
        f.writes = f.writes + 1
        f.settings[key] = value
      end,
    },
    alert = { show = function(message) table.insert(f.alerts, message) end },
    dialog = {
      blockAlert = function()
        f.confirmations = (f.confirmations or 0) + 1
        if f.duringConfirmation then f.duringConfirmation() end
        return f.confirmation
      end,
    },
    json = { encode = function(value) lastEncoded = value; return "{}" end },
    timer = {
      doAfter = function(_, callback)
        local timer = { callback = callback }
        function timer:stop() self.stopped = true end
        table.insert(f.timers, timer)
        return timer
      end,
    },
    webview = {
      usercontent = {
        new = function(name)
          local content = { name = name }
          function content:setCallback(callback) self.callback = callback; return self end
          return content
        end,
      },
      new = function(frame, preferences, content)
        local view = { frame = frame, preferences = preferences, content = content, updates = {} }
        for _, method in ipairs({ "windowStyle", "windowTitle", "allowTextEntry", "closeOnEscape", "deleteOnClose" }) do
          view[method] = function(self, value) self[method .. "Value"] = value; return self end
        end
        function view:policyCallback(callback) self.policy = callback; return self end
        function view:windowCallback(callback) self.closingCallback = callback; return self end
        function view:html(value) self.source = value; return self end
        function view:show() self.shown = true; return self end
        function view:bringToFront() self.frontCount = (self.frontCount or 0) + 1; return self end
        function view:hswindow() return f.panel end
        function view:evaluateJavaScript(script)
          self.script = script
          table.insert(self.updates, lastEncoded)
          return self
        end
        function view:delete() self.deleted = true end
        table.insert(f.views, view)
        return view
      end,
    },
  }
  f.workspace = dofile(repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/init.lua")
  function f:open()
    self.workspace:promptCaptureCurrentWorkspace()
    return self.views[#self.views]
  end
  function f:send(action, name)
    local view = self.views[#self.views]
    if view.content.callback then view.content.callback({ body = { action = action, name = name } }) end
  end
  function f:drain()
    while #self.timers > 0 do
      local timer = table.remove(self.timers, 1)
      if not timer.stopped then timer.callback() end
    end
  end
  function f:capture() self:send("capture"); self:drain() end
  function f:recipe(name) return self.settings.TheseusWorkspaceRecipesV1.recipes[name] end
  return f
end

local f = fixture()
local view = f:open()
equal(view.shown, true, "show capture panel immediately")
equal(f.enumerations, 0, "let the panel paint before collecting windows")
equal(f.workspace._captureDialog.state, "capturing", "initial capture state")
equal(view.source:find('id="name" type="text" maxlength="80" autocomplete="off" disabled', 1, true) ~= nil, true, "name field initially disabled")
equal(view.source:find('id="save" type="submit" disabled', 1, true) ~= nil, true, "Save initially disabled")
equal(view.preferences.privateBrowsing, true, "no persistent web data")
equal(view.policy("navigationAction", view, { request = { URL = "about:blank" } }), true, "allow local HTML")
equal(view.policy("navigationAction", view, { request = { URL = { __luaSkinType = "NSURL", url = "about:blank" } } }), true, "allow native NSURL local HTML")
equal(view.policy("navigationAction", view, { request = { URL = "https://example.com" } }), false, "deny remote navigation")
equal(view.policy("navigationAction", view, { request = { URL = { __luaSkinType = "NSURL", url = "https://example.com" } } }), false, "deny native NSURL remote navigation")
equal(view.policy("navigationAction", view, { request = { URL = {} } }), false, "deny unknown structured URL")
equal(view.policy("newWindow"), false, "deny extra browser windows")
equal(view.policy("authenticationChallenge"), false, "deny authentication")
f:send("save", "Too early")
equal(f.writes, 0, "Lua also rejects Save before capture completion")
f:open()
equal(#f.views, 1, "repeated hotkey reuses the existing panel")
f:send("capture")
f:send("capture")
equal(#f.timers, 1, "only start one snapshot")
f:drain()
equal(f.workspace._captureDialog.state, "ready", "enable naming only when snapshot is complete")
equal(f.enumerations, 1, "one application-window enumeration")
equal(f.safari.reads, 1, "read Safari frame once")
equal(f.ghostty.reads, 1, "read Ghostty frame once")
equal(f.panel.reads, 0, "exclude capture panel before inspecting its geometry")
equal(f.writes, 0, "ready snapshot is not saved until named")
equal(view.updates[#view.updates].message:find("2 windows", 1, true) ~= nil, true, "ready status has eligible count")

-- Reproduce the reported race: move Ghostty after readiness, before Save.
-- Mutate the original tables too, guarding against aliased geometry snapshots.
f.ghostty.currentFrame.x = 100
f.ghostty.currentFrame.w = 400
f.screenFrame.w = 3200
f.spaceID = 902
f:send("save", "  Frozen Atlas  ")
local recipe = f:recipe("Frozen Atlas")
equal(recipe.name, "Frozen Atlas", "normalize the saved name")
equal(#recipe.windows, 2, "do not save the capture panel")
near(recipe.windows[2].frame.x, 0.5, "save original Ghostty x, not its moved position")
near(recipe.windows[2].frame.w, 0.5, "save original Ghostty width and screen dimensions")
equal(f.enumerations, 1, "Save never re-enumerates windows")
equal(f.ghostty.reads, 1, "Save never re-reads live geometry")
equal(f.workspace._captureDialog, nil, "release saved snapshot and panel")
equal(view.deleted, true, "delete panel after successful save")
equal(#f.alerts, 1, "one saved completion notice")

f = fixture()
view = f:open()
f:send("capture")
f:send("cancel")
f:drain()
equal(f.enumerations, 0, "Cancel stops the queued capture")
equal(f.writes, 0, "Cancel does not save")
equal(f.workspace._captureDialog, nil, "Cancel releases panel")
equal(view.deleted, true, "Cancel deletes panel")

f = fixture()
view = f:open()
f:capture()
f:send("save", "   ")
equal(f.workspace._captureDialog.state, "ready", "invalid name allows correction")
equal(f.writes, 0, "invalid name does not save")
f:send("cancel")
equal(f.writes, 0, "Cancel discards a ready snapshot")

f = fixture()
f:open()
f:capture()
f.saveError = true
f:send("save", "Retry")
equal(f.workspace._captureDialog.state, "ready", "failed settings write allows retry")
equal(f.writes, 0, "failed write is not success")
f.saveError = false
f.ghostty.currentFrame.x = 100
f:send("save", "Retry")
near(f:recipe("Retry").windows[2].frame.x, 0.5, "save retry keeps frozen geometry")
equal(f.enumerations, 1, "save retry does not recapture")

f = fixture()
f.workspace:captureCurrentWorkspace("Existing", { silent = true })
local originalRecipe = f:recipe("Existing")
f.ghostty.currentFrame.x = 500
f:open()
f:capture()
f:send("save", "Existing")
equal(f.confirmations, 1, "duplicate name requires confirmation")
equal(f:recipe("Existing"), originalRecipe, "declined replacement preserves recipe")
equal(f.workspace._captureDialog.state, "ready", "declined replacement keeps naming available")
f.confirmation = "Replace"
f.duringConfirmation = function() f.ghostty.currentFrame.x = 1200 end
f:send("save", "Existing")
near(f:recipe("Existing").windows[2].frame.x, 0.25, "replacement confirmation uses the frozen frame")
equal(f.enumerations, 2, "one enumeration per capture, none for confirmation")

f = fixture()
f:open()
f:capture()
local sibling = f.workspace:captureCurrentWorkspace("Sibling", { silent = true })
f:send("save", "Panel")
equal(f:recipe("Sibling"), sibling, "preserve catalog changes made while naming")
equal(f:recipe("Panel").name, "Panel", "add snapshot to latest catalog")

for _, scenario in ipairs({ "empty", "Space-before", "Space-during", "app-enumeration", "Space-enumeration" }) do
  f = fixture()
  f:open()
  if scenario == "empty" then f.windowIDs = { 99 }
  elseif scenario == "Space-before" then f.spaceID = 902
  elseif scenario == "Space-during" then f.afterEnumeration = function() f.spaceID = 902 end
  elseif scenario == "app-enumeration" then f.enumerationError = true
  else f.spaceEnumerationError = true end
  f:capture()
  equal(f.workspace._captureDialog.state, "failed", scenario .. " fails closed")
  f:send("save", "Must not save")
  equal(f.writes, 0, scenario .. " cannot save an invalid snapshot")
  f:send("cancel")
end

f = fixture()
view = f:open()
f:send("capture")
f.workspace:stop()
f:drain()
equal(f.enumerations, 0, "Spoon stop cancels queued capture")
equal(f.workspace._captureDialog, nil, "Spoon stop releases dialog")
equal(view.deleted, true, "Spoon stop deletes dialog")

f = fixture()
view = f:open()
f:send("capture")
view.closingCallback("closing", view)
f:drain()
equal(f.enumerations, 0, "native window close cancels queued capture")
equal(f.workspace._captureDialog, nil, "native window close releases session")

f = fixture()
f.spaceType = "fullscreen"
f:open()
equal(#f.views, 0, "reject incompatible Space before opening panel")
equal(f.enumerations, 0, "do not enumerate an incompatible Space")

hs = previousHs
print(string.format("workspace_capture_spec: %d assertions passed", assertions))
