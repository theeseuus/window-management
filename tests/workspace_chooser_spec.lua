local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local spoonPath = repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/"
local logic = dofile(spoonPath .. "workspace_logic.lua")
local assertions = 0

local function equal(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local function clone(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, item in pairs(value) do copy[key] = clone(item) end
  return copy
end

local catalog, settingsWrites, failSave
local choosers, hotkeys, menus, alerts, prompts, restores = {}, {}, {}, {}, {}, {}
local response, duringPrompt, chooseMenu = "Cancel", nil, true
local completeOnHide, failHotkey, failMenu = false, false, false
local menuOpen = false

local function resetCatalog(names)
  catalog = logic.newCatalog()
  settingsWrites, failSave = 0, false
  for _, name in ipairs(names or { "Alpha", "Zeta" }) do
    catalog.recipes[name] = assert(logic.buildRecipe(name, { {
      bundleID = "com.example.Test",
      appName = "Test",
      frame = { x = 0, y = 0, w = 800, h = 600 },
      screenFrame = { x = 0, y = 0, w = 1600, h = 1000 },
    } }, "2026-10-05T00:00:00Z"))
  end
end

local previousHs = hs
hs = {
  settings = {
    get = function() return clone(catalog) end,
    set = function(_, value)
      if failSave then error("test save failure") end
      settingsWrites = settingsWrites + 1
      catalog = clone(value)
    end,
  },
  screen = { mainScreen = function() return {} end },
  alert = { show = function(message) table.insert(alerts, message) end },
  window = setmetatable({}, { __index = function()
    error("chooser deletion must not inspect or move any windows")
  end }),
  spaces = setmetatable({}, { __index = function()
    error("chooser deletion must not inspect or change Spaces")
  end }),
  chooser = {
    new = function(completion)
      local chooser = { completion = completion, queryText = "", row = 1, visible = false }
      function chooser:placeholderText(text) self.placeholder = text; return self end
      function chooser:searchSubText(value) self.searchSubtext = value; return self end
      function chooser:choices(values) self.values = values; return self end
      function chooser:showCallback(callback) self.onShow = callback; return self end
      function chooser:hideCallback(callback) self.onHide = callback; return self end
      function chooser:rightClickCallback(callback) self.onRightClick = callback; return self end
      function chooser:isVisible() return self.visible end
      function chooser:show()
        self.visible = true
        if self.onShow then self.onShow() end
        return self
      end
      function chooser:hide()
        self.visible = false
        if self.onHide then self.onHide() end
        if completeOnHide then self.completion(nil) end
        return self
      end
      function chooser:cancel() self:hide(); self.completion(nil); return self end
      function chooser:delete() self.deleted = true end
      function chooser:query(value)
        if value == nil then return self.queryText end
        self.queryText = value
        return self
      end
      function chooser:selectedRow(value)
        if value == nil then return self.row end
        self.row = value
        return self
      end
      function chooser:selectedRowContents(row)
        local visible = {}
        for _, choice in ipairs(self.values) do
          local searchable = choice.text .. " " .. choice.subText
          if searchable:lower():find(self.queryText:lower(), 1, true) then
            table.insert(visible, choice)
          end
        end
        return visible[row or self.row] or {}
      end
      table.insert(choosers, chooser)
      return chooser
    end,
  },
  hotkey = {
    new = function(modifiers, key, callback)
      if failHotkey then return nil end
      local hotkey = { modifiers = modifiers, key = key, callback = callback, enabled = false }
      function hotkey:enable() self.enabled = true; return self end
      function hotkey:disable()
        if self.deleted then error("must not disable an already deleted hotkey") end
        self.enabled = false
        return self
      end
      function hotkey:delete() self.enabled = false; self.deleted = true end
      table.insert(hotkeys, hotkey)
      return hotkey
    end,
  },
  menubar = {
    new = function(inMenuBar)
      if failMenu then return nil end
      local menu = { inMenuBar = inMenuBar }
      function menu:setMenu(items) self.items = items; return self end
      function menu:popupMenu(point)
        self.point = point
        menuOpen = true
        if chooseMenu then self.items[1].fn() end
        menuOpen = false
        return self
      end
      function menu:delete() self.deleted = true end
      table.insert(menus, menu)
      return menu
    end,
  },
  mouse = { absolutePosition = function() return { x = 40, y = 50 } end },
  dialog = {
    blockAlert = function(message, detail, first, second, style)
      local chooser, hotkey = choosers[#choosers], hotkeys[#hotkeys]
      equal(chooser:isVisible(), false, "hide chooser during confirmation")
      if not failHotkey then equal(hotkey.enabled, false, "disable local hotkey during confirmation") end
      equal(menuOpen, false, "close context menu before confirmation")
      table.insert(prompts, { message = message, detail = detail, first = first, second = second, style = style })
      if duringPrompt then duringPrompt() end
      return response
    end,
  },
}

local workspace = dofile(spoonPath .. "init.lua")
workspace.restoreWorkspace = function(_, name) table.insert(restores, name) end

local function open(names)
  workspace:stop()
  resetCatalog(names)
  response, duringPrompt, chooseMenu, completeOnHide = "Cancel", nil, true, false
  workspace:showRestoreChooser()
  return choosers[#choosers], hotkeys[#hotkeys]
end

local chooser, hotkey = open()
equal(chooser:isVisible(), true, "open restore chooser")
equal(#chooser.values, 2, "show saved layouts")
equal(chooser.searchSubtext, true, "retain application search")
equal(chooser.placeholder:find("right-click", 1, true) ~= nil, true, "discover deletion in chooser")
equal(#hotkey.modifiers, 1, "no Hyper modifier on local deletion")
equal(hotkey.modifiers[1], "cmd", "local Command modifier")
equal(hotkey.key, "delete", "local Delete key")
equal(hotkey.enabled, true, "enable only while chooser is open")

chooser:query("Zeta"):selectedRow(1)
hotkey.callback()
equal(prompts[#prompts].detail:find("“Zeta”", 1, true) ~= nil, true, "name filtered selection in confirmation")
equal(prompts[#prompts].first, "Cancel", "Cancel is the default confirmation action")
equal(prompts[#prompts].second, "Delete", "Delete requires explicit selection")
equal(settingsWrites, 0, "Cancel performs no settings write")
equal(catalog.recipes.Zeta ~= nil, true, "Cancel keeps layout")
equal(chooser:query(), "Zeta", "Cancel preserves search")
equal(chooser:selectedRow(), 1, "Cancel preserves selection")
equal(chooser:isVisible(), true, "Cancel reopens chooser")
equal(hotkey.enabled, true, "Cancel restores local gesture")
equal(#restores, 0, "Cancel never restores windows")

response = "Delete"
completeOnHide = true
hotkey.callback()
equal(catalog.recipes.Zeta, nil, "Delete removes filtered layout, not original row index")
equal(catalog.recipes.Alpha ~= nil, true, "Delete preserves other layouts")
equal(settingsWrites, 1, "Delete persists one catalog change")
equal(#chooser.values, 1, "refresh chooser after deletion")
equal(chooser:query(), "Zeta", "Delete retains search")
equal(alerts[#alerts], "DELETED Zeta", "show deletion result")
equal(#restores, 0, "hiding for confirmation never restores windows")
local promptCount = #prompts
hotkey.callback()
equal(#prompts, promptCount, "ignore deletion when search has no selectable row")

completeOnHide = false
chooser:query("")
chooser.completion(chooser:selectedRowContents())
equal(restores[#restores], "Alpha", "Return retains normal restore behavior")
equal(workspace._restoreChooser, nil, "restore releases chooser")
equal(chooser.deleted, true, "restore destroys chooser")
equal(hotkey.deleted, true, "restore destroys local hotkey")
equal(hotkey.enabled, false, "local gesture cannot leak into applications")

chooser, hotkey = open()
promptCount = #prompts
chooser.onRightClick(0)
chooser.onRightClick(99)
equal(#prompts, promptCount, "ignore right-click outside valid rows")
chooseMenu = false
chooser.onRightClick(2)
equal(#prompts, promptCount, "dismissing context menu does not delete")
equal(menus[#menus].inMenuBar, false, "context menu creates no menu-bar icon")
equal(menus[#menus].deleted, true, "release dismissed context menu")
chooseMenu, response = true, "Delete"
chooser:query("Zeta")
chooser.onRightClick(1)
equal(menus[#menus].items[1].title, "Delete saved layout…", "label context action")
equal(menus[#menus].deleted, true, "release selected context menu")
equal(catalog.recipes.Zeta, nil, "right-click uses filtered visible row")
equal(catalog.recipes.Alpha ~= nil, true, "right-click preserves other layouts")
chooser:cancel()
equal(workspace._restoreChooser, nil, "Escape releases chooser")
equal(hotkey.deleted, true, "Escape releases local hotkey")

chooser, hotkey = open()
local staleChooser, staleHotkey = chooser, hotkey
workspace:showRestoreChooser()
equal(staleChooser.deleted, true, "replacement destroys previous chooser")
equal(staleHotkey.deleted, true, "replacement destroys previous hotkey")
promptCount = #prompts
staleHotkey.callback()
staleChooser.onRightClick(1)
staleChooser.completion({ workspaceName = "Alpha" })
equal(#prompts, promptCount, "stale callbacks cannot open deletion prompt")
equal(settingsWrites, 0, "stale callbacks cannot delete")
equal(#restores, 1, "stale callbacks cannot restore")

chooser, hotkey = open()
response = "Delete"
duringPrompt = function() workspace:stop() end
hotkey.callback()
equal(settingsWrites, 0, "stop invalidates pending deletion")
equal(catalog.recipes.Alpha ~= nil, true, "stop keeps pending target")
equal(hotkey.deleted, true, "stop destroys local hotkey")
equal(chooser.deleted, true, "stop destroys hidden chooser")

chooser, hotkey = open()
response = "Delete"
duringPrompt = function() workspace:showRestoreChooser() end
hotkey.callback()
equal(settingsWrites, 0, "replacement invalidates pending deletion")
equal(workspace._restoreChooser ~= chooser, true, "retain replacement chooser")
equal(workspace._restoreChooser:isVisible(), true, "replacement chooser remains usable")

chooser, hotkey = open()
response = "Delete"
duringPrompt = function() catalog.recipes.Alpha = nil end
hotkey.callback()
equal(settingsWrites, 0, "missing target is not persisted as a deletion")
equal(catalog.recipes.Zeta ~= nil, true, "missing target preserves surviving recipe")
equal(alerts[#alerts], "WORKSPACE: workspace was not found", "report stale target")
equal(#chooser.values, 1, "refresh stale catalog after prompt")

chooser, hotkey = open()
response, failSave = "Delete", true
hotkey.callback()
equal(settingsWrites, 0, "failed save performs no successful write")
equal(catalog.recipes.Alpha ~= nil, true, "failed save retains layout")
equal(alerts[#alerts]:find("could not save", 1, true) ~= nil, true, "report save failure")
equal(chooser:isVisible(), true, "failed save reopens chooser")

chooser, hotkey = open({ "Final \"draft\"" })
response = "Delete"
hotkey.callback()
equal(prompts[#prompts].detail:find("Final \"draft\"", 1, true) ~= nil, true, "preserve punctuation in exact target name")
equal(next(catalog.recipes), nil, "delete final layout")
equal(workspace._restoreChooser, nil, "close empty chooser")
equal(hotkey.deleted, true, "final deletion releases local gesture")
equal(alerts[#alerts], "DELETED Final \"draft\"", "preserve final deletion notice")
promptCount = #prompts
hotkey.callback()
equal(#prompts, promptCount, "released local gesture cannot open prompt")

failHotkey = true
chooser = open()
response = "Delete"
chooser.onRightClick(1)
equal(catalog.recipes.Alpha, nil, "context action works if local hotkey cannot be allocated")
failHotkey = false
chooser, hotkey = open()
failMenu = true
promptCount = #prompts
chooser.onRightClick(1)
equal(#prompts, promptCount, "failed menu allocation does not delete")
response = "Delete"
hotkey.callback()
equal(catalog.recipes.Alpha, nil, "keyboard action works without context menu")
failMenu = false

workspace:stop()
resetCatalog({})
local chooserCount = #choosers
workspace:showRestoreChooser()
equal(#choosers, chooserCount, "empty catalog creates no chooser or local hotkey")
equal(alerts[#alerts], "WORKSPACE: no captured workspaces", "report empty catalog")
catalog.schemaVersion = 999
workspace:showRestoreChooser()
equal(#choosers, chooserCount, "invalid catalog creates no chooser")
equal(alerts[#alerts]:find("workspace settings are invalid", 1, true) ~= nil, true, "report invalid catalog")
equal(#restores, 1, "only explicit normal selection invoked restore")

hs = previousHs
print(string.format("workspace_chooser: %d assertions passed", assertions))
