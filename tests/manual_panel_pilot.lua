-- Run with dofile("/absolute/repo/path/tests/manual_panel_pilot.lua") in the
-- Hammerspoon Console. All recipes are in memory, capture is synthetic, and
-- Restore/Establish only print receipts. No real windows or settings change.
local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local sourcePath = testPath .. "../Hammerspoon/TheseusWorkspace.spoon/"
local controller = dofile(sourcePath .. "panel_controller.lua")
local logic = dofile(sourcePath .. "workspace_logic.lua")
local catalog = logic.newCatalog()

local function context()
  local screen = hs.screen.mainScreen()
  return { screen = screen, screenFrame = screen:frame(), spaceID = hs.spaces.activeSpaceOnScreen(screen) }
end

local function records(ai, cli)
  local screenFrame = context().screenFrame
  local slots = {
    { "com.apple.finder", "Finder", 0, 0, .25, .25 },
    { "com.apple.finder", "Finder", 0, .25, .25, .25 },
    { "com.mitchellh.ghostty", "Ghostty", .25, 0, cli and .5 or .25, .5 },
    { "com.apple.Safari", "Safari", cli and 0 or .5, .5, .5, .5 },
  }
  if ai then slots[#slots + 1] = { "com.example." .. ai, ai, 0, .5, .5, .5 } end
  local result = {}
  for _, slot in ipairs(slots) do
    result[#result + 1] = {
      bundleID = slot[1], appName = slot[2], screenFrame = screenFrame,
      frame = logic.absoluteFrame({ x = slot[3], y = slot[4], w = slot[5], h = slot[6] }, screenFrame),
    }
  end
  return result
end

for _, item in ipairs({ { "Claude Workspace", "Claude" }, { "CLI Workspace", nil, true }, { "GPT Workspace", "ChatGPT" } }) do
  catalog.recipes[item[1]] = assert(logic.buildRecipe(item[1], records(item[2], item[3]), "2026-10-07T00:00:00Z"))
end

local pilot = controller.new({
  context = context,
  catalog = function() return catalog end,
  snapshot = function(ctx)
    return { records = records("ChatGPT"), capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"), context = ctx }
  end,
  save = function(name, snapshot)
    local recipe, err = logic.buildRecipe(name, snapshot.records, snapshot.capturedAt)
    if recipe then catalog.recipes[name] = recipe end
    return recipe, err
  end,
  delete = function(name) catalog.recipes[name] = nil; return true end,
  apply = function(action, name, ctx)
    print("PANEL-PILOT-ACTION " .. hs.json.encode({ action = action, name = name, spaceID = ctx.spaceID }))
  end,
  busy = function() return nil end,
  reason = function(err) return tostring(err) end,
  alert = function(err) print("PANEL-PILOT-ERROR " .. err) end,
})

if workspacePanelPilot then workspacePanelPilot:close() end
workspacePanelPilot = pilot
pilot:show()
print("PANEL-PILOT-OPEN: synthetic capture, memory-only recipes, placement disabled")
return pilot
