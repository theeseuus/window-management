local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = testPath:match("^(.*)/tests/$")
local logic = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/workspace_logic.lua")
local display = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/panel_logic.lua")
local fixture = {}

function fixture.new()
  local f = {
    settings = {}, writes = 0, enumerations = 0, views = {}, timers = {}, alerts = {}, hotkeys = {},
    spaceID = 901, windowIDs = { 11, 21, 99 }, restores = {}, establishes = {},
    screenFrame = { x = 100, y = 50, w = 1600, h = 1000 },
  }
  local screen = {}
  function screen:id() return 1 end
  function screen:frame() return f.screenFrame end
  local function window(id, bundleID, appName, frame)
    local app = {}
    function app:bundleID() return bundleID end
    function app:title() return appName end
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
  f.panel = window(99, "org.hammerspoon.Hammerspoon", "Hammerspoon", { x = 500, y = 300, w = 660, h = 520 })
  hs = {
    screen = { mainScreen = function() return screen end },
    drawing = { windowBehaviors = { moveToActiveSpace = 2 } },
    window = {
      focusedWindow = function() return f.focusedWindow or f.safari end,
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
      get = function(key) return display.copy(f.settings[key]) end,
      set = function(key, value)
        if f.saveError then error("settings write unavailable") end
        f.writes = f.writes + 1
        f.settings[key] = display.copy(value)
      end,
    },
    alert = { show = function(message) table.insert(f.alerts, message) end },
    json = { encode = function(value) f.lastEncoded = display.copy(value); return "{}" end },
    timer = {
      doAfter = function(_, callback)
        local timer = { callback = callback }
        function timer:stop() self.stopped = true end
        table.insert(f.timers, timer)
        return timer
      end,
    },
    hotkey = {
      bindSpec = function(spec, callback)
        local key = { spec = spec, callback = callback }
        function key:delete() self.deleted = true end
        table.insert(f.hotkeys, key)
        return key
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
        if f.openError then error("native view unavailable") end
        local view = { frame = frame, preferences = preferences, content = content, updates = {} }
        for _, method in ipairs({ "windowStyle", "windowTitle", "allowTextEntry", "allowNewWindows",
          "closeOnEscape", "deleteOnClose", "transparent", "behavior" }) do
          view[method] = function(self, value) self[method .. "Value"] = value; return self end
        end
        function view:policyCallback(callback) self.policy = callback; return self end
        function view:windowCallback(callback) self.closingCallback = callback; return self end
        function view:html(value) self.source = value; return self end
        function view:show() self.shown = true; return self end
        function view:bringToFront() self.frontCount = (self.frontCount or 0) + 1; return self end
        function view:hswindow() return f.panel end
        function view:evaluateJavaScript(script, callback)
          self.script = script
          table.insert(self.updates, f.lastEncoded)
          if callback then callback(nil, f.renderError) end
          return self
        end
        function view:delete() self.deleted = true end
        table.insert(f.views, view)
        return view
      end,
    },
  }
  f.workspace = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/init.lua")
  function f:session() return self.workspace._workspaceUI and self.workspace._workspaceUI.session end
  function f:send(action, name, revision)
    local view, session = self.views[#self.views], self:session()
    if view and view.content.callback then
      view.content.callback({ body = { action = action, name = name, revision = revision or (session and session.revision) } })
    end
  end
  function f:open(capture)
    if capture then self.workspace:promptCaptureCurrentWorkspace() else self.workspace:showWorkspaces() end
    local session = self:session()
    if session and not session.loaded then self:send("ready") end
    return self.views[#self.views]
  end
  function f:drain()
    while #self.timers > 0 do
      local timer = table.remove(self.timers, 1)
      if not timer.stopped then timer.callback() end
    end
  end
  function f:capture() self:send("capture"); self:drain() end
  function f:recipe(name)
    local catalog = self.settings.TheseusWorkspaceRecipesV1
    return catalog and catalog.recipes[name]
  end
  function f:seed(names)
    local catalog = logic.newCatalog()
    for _, name in ipairs(names or { "Alpha", "Zeta" }) do
      catalog.recipes[name] = assert(logic.buildRecipe(name, { {
        bundleID = "com.example.Test", appName = "Test",
        frame = { x = 0, y = 0, w = 800, h = 600 },
        screenFrame = { x = 0, y = 0, w = 1600, h = 1000 },
      } }, "2026-10-07T00:00:00Z"))
    end
    self.settings.TheseusWorkspaceRecipesV1 = catalog
  end
  function f:model() local view = self.views[#self.views]; return view.updates[#view.updates] end
  return f
end

return fixture
