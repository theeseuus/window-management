local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = testPath:match("^(.*)/tests/$")
local logic = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/panel_logic.lua")
local workspace = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/workspace_logic.lua")
local assertions = 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local recipe = assert(workspace.buildRecipe("Live geometry", {
  { bundleID = "com.example.Finder", appName = "Finder", frame = { x = 0, y = 0, w = 250, h = 250 }, screenFrame = { x = 0, y = 0, w = 1000, h = 1000 } },
  { bundleID = "com.example.Finder", appName = "Finder", frame = { x = 0, y = 250, w = 250, h = 250 }, screenFrame = { x = 0, y = 0, w = 1000, h = 1000 } },
  { bundleID = "com.example.Terminal", appName = "Ghostty", frame = { x = 250, y = 0, w = 250, h = 500 }, screenFrame = { x = 0, y = 0, w = 1000, h = 1000 } },
}, "2026-10-07T00:00:00Z"))
local model = logic.describe(recipe)
equal(model.windowCount, 3, "one outline per saved slot")
equal(model.summary, "Finder × 2, Ghostty", "separate sorted app summary")
equal(#model.applications, 2, "group repeat applications")
equal(model.rectangles[2].y, .25, "actual saved vertical position")
equal(model.rectangles[3].h, .5, "actual saved height")
model.rectangles[1].x = .75
equal(recipe.windows[1].frame.x, 0, "preview never aliases recipe geometry")
local copy = logic.copy(recipe)
equal(logic.sameRecipe(recipe, copy), true, "deep comparison ignores table identity")
copy.windows[1].frame.x = .1
equal(logic.sameRecipe(recipe, copy), false, "changed geometry invalidates confirmation")
equal(logic.sameRecipe(recipe, nil), false, "deleted recipe invalidates confirmation")
copy = logic.copy(recipe)
copy.capturedAt = "different"
equal(logic.sameRecipe(recipe, copy), false, "recapture invalidates confirmation")
copy = logic.copy(recipe)
copy.windows[1].frame.x, copy.windows[1].frame.w = -.5, 2
local clamped = logic.describe(copy)
equal(clamped.rectangles[1].x, 0, "preview uses placement clamping")
equal(clamped.rectangles[1].w, 1, "oversized frame preview fits screen")
equal(copy.windows[1].frame.w, 2, "preview does not rewrite stored geometry")
local catalog = workspace.newCatalog()
for _, name in ipairs({ "Zeta", "alpha", "Alpha", "<script>" }) do
  local named = logic.copy(recipe); named.name = name; catalog.recipes[name] = named
end
local entries = logic.entries(catalog)
equal(entries[1].name, "<script>", "model preserves literal names for safe text rendering")
equal(entries[2].name, "Alpha", "stable tie breaker for case-folded names")
equal(entries[3].name, "alpha", "deterministic case-folded ordering")
equal(entries[4].name, "Zeta", "sorted recipe order")
equal(entries[1].capturedAt, nil, "no raw timestamps in display model")
equal(entries[1].rectangles[1].bundleID, nil, "preview needs no application credentials or identifiers")
print(string.format("panel_logic_spec: %d assertions passed", assertions))
