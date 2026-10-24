local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = testPath:match("^(.*)/tests/$")
local originalHS = hs
local assertions, active, focused, failAt = 0, 0, 0, nil
local bindings = {}
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local screen = { id = function() return 1 end }
local function window(id, x)
  return {
    id = function() return id end,
    screen = function() return screen end,
    frame = function() return { x = x, y = 0, w = 100, h = 100 } end,
    isStandard = function() return true end,
    isVisible = function() return true end,
    isMinimized = function() return false end,
    isFullScreen = function() return false end,
    focus = function() focused = id end,
  }
end
local current, right = window(1, 0), window(2, 200)
hs = {
  eventtap = { event = { types = {} } }, keycodes = { map = {} },
  printf = function() end,
  hotkey = { bind = function(mods, key, callback) bindings[table.concat(mods, "+") .. ":" .. key] = callback end },
  window = {
    focusedWindow = function() return current end,
    switcher = { new = function() return { ui = {} } end },
    filter = { new = function()
      local filter = {}
      function filter:setOverrideFilter(rules)
        if rules.currentSpace then
          self.tracking = true
          active = active + 1
          equal(rules.visible, true, "visible windows retained")
          equal(rules.fullscreen, false, "fullscreen excluded")
          equal(rules.allowRoles[1], "AXStandardWindow", "standard windows retained")
          if failAt == "setup" then error("setup failed") end
        end
      end
      function filter:getWindows()
        equal(self.tracking, true, "track current Space during collection")
        if failAt == "collection" then error("collection failed") end
        return { current, right }
      end
      function filter:delete()
        if self.tracking then active = active - 1; self.tracking = false end
      end
      return filter
    end },
  },
}
local spoon = dofile(root .. "/Hammerspoon/TheseusWindow.spoon/init.lua")
equal(active, 0, "loading does not retain Space-aware filter")
spoon:bindHotkeys():start()
equal(active, 0, "binding and starting do not retain Space-aware filter")
local focusRight = bindings["ctrl+alt+cmd:l"]
equal(type(focusRight), "function", "directional shortcut retained")
equal(type(bindings["ctrl+alt+cmd:left"]), "function", "Space shortcut retained")
focusRight()
equal(focused, 2, "directional command focuses nearest right window")
equal(active, 0, "release tracking after success")
for _, failure in ipairs({ "collection", "setup" }) do
  failAt = failure
  focused = 0
  focusRight()
  equal(focused, 0, "do not focus after " .. failure .. " failure")
  equal(active, 0, "release tracking after " .. failure .. " failure")
end
local geometryKeys = { "ctrl+alt+cmd:-", "ctrl+alt+cmd+shift:-", "ctrl+alt+cmd:=", "ctrl+alt+cmd+shift:=",
  "ctrl+alt+cmd:2", "ctrl+alt+cmd+shift:2", "ctrl+alt+cmd:3", "ctrl+alt+cmd+shift:3",
  "ctrl+alt+cmd:4", "ctrl+alt+cmd+shift:4", "ctrl+alt+cmd:8", "ctrl+alt+cmd+shift:8",
  "ctrl+alt+cmd:up", "ctrl+alt+cmd:down", "ctrl+alt+cmd:[", "ctrl+alt+cmd:]",
  "ctrl+alt+cmd:return", "ctrl+alt+cmd+shift:return", "ctrl+alt+cmd:d" }
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","default fallback retains " .. key) end
bindings = {}; spoon.geometryHotkeys = false; spoon:bindHotkeys()
for _,key in ipairs(geometryKeys) do equal(bindings[key],nil,"native pilot releases " .. key) end
for _,key in ipairs({"ctrl+alt+cmd:l","ctrl+alt+cmd:left","ctrl+alt+cmd:s","ctrl+alt+cmd+shift:s","ctrl+alt+cmd:w"}) do
  equal(type(bindings[key]),"function","unported controls retained " .. key)
end
bindings = {}; spoon.geometryHotkeys = true; spoon:bindHotkeys()
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","fallback restores " .. key) end
bindings = {}; spoon.focusHotkeys = false; spoon:bindHotkeys()
for _,key in ipairs({"h","j","k","l"}) do equal(bindings["ctrl+alt+cmd:" .. key],nil,"native focus releases " .. key) end
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","focus handoff retains geometry " .. key) end
for _,key in ipairs({"left","s","w"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","focus handoff retains " .. key) end
bindings = {}; spoon.focusHotkeys = true; spoon:bindHotkeys()
for _,key in ipairs({"h","j","k","l"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","fallback restores focus " .. key) end
bindings = {}; spoon.stashHotkeys = false; spoon:bindHotkeys()
equal(bindings["ctrl+alt+cmd:s"],nil,"native stash releases only S")
equal(type(bindings["ctrl+alt+cmd+shift:s"]),"function","accordion remains in Hammerspoon")
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","stash handoff retains geometry " .. key) end
for _,key in ipairs({"h","j","k","l"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","stash handoff retains focus " .. key) end
bindings = {}; spoon.stashHotkeys = true; spoon:bindHotkeys()
equal(type(bindings["ctrl+alt+cmd:s"]),"function","fallback restores stash S")
bindings = {}; spoon.switcherHotkeys = false; spoon:bindHotkeys()
equal(bindings["ctrl+alt+cmd:w"],nil,"native switcher releases forward W")
equal(bindings["ctrl+alt+cmd+shift:w"],nil,"native switcher releases reverse W")
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","switcher handoff retains geometry " .. key) end
for _,key in ipairs({"h","j","k","l","s","left","right"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","switcher handoff retains " .. key) end
equal(type(bindings["ctrl+alt+cmd+shift:s"]),"function","accordion remains in Hammerspoon after switcher handoff")
bindings = {}; spoon.switcherHotkeys = true; spoon:bindHotkeys()
equal(type(bindings["ctrl+alt+cmd:w"]),"function","fallback restores forward W")
equal(type(bindings["ctrl+alt+cmd+shift:w"]),"function","fallback restores reverse W")
bindings = {}; spoon.accordionHotkeys = false; spoon:bindHotkeys()
equal(bindings["ctrl+alt+cmd+shift:s"],nil,"native accordion releases only Shift+S")
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","accordion handoff retains geometry " .. key) end
for _,key in ipairs({"h","j","k","l","s","w","left","right"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","accordion handoff retains " .. key) end
bindings = {}; spoon.accordionHotkeys = true; spoon:bindHotkeys()
equal(type(bindings["ctrl+alt+cmd+shift:s"]),"function","fallback restores accordion")
bindings = {}; spoon.spaceMoveHotkeys = false; spoon:bindHotkeys()
equal(bindings["ctrl+alt+cmd:left"],nil,"native Space handoff releases left")
equal(bindings["ctrl+alt+cmd:right"],nil,"native Space handoff releases right")
for _,key in ipairs(geometryKeys) do equal(type(bindings[key]),"function","Space handoff retains geometry " .. key) end
for _,key in ipairs({"h","j","k","l","s","w"}) do equal(type(bindings["ctrl+alt+cmd:" .. key]),"function","Space handoff retains " .. key) end
equal(type(bindings["ctrl+alt+cmd+shift:s"]),"function","Space handoff retains accordion")
bindings = {}; spoon.spaceMoveHotkeys = true; spoon:bindHotkeys()
equal(type(bindings["ctrl+alt+cmd:left"]),"function","fallback restores left")
equal(type(bindings["ctrl+alt+cmd:right"]),"function","fallback restores right")
hs = originalHS
print(string.format("window_filter_lifecycle_spec: %d assertions passed", assertions))
