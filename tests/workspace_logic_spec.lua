local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWorkspace.spoon/workspace_logic.lua"
)

local assertions = 0

local function equal(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(
      string.format(
        "%s: expected %s, got %s",
        label,
        tostring(expected),
        tostring(actual)
      ),
      2
    )
  end
end

local function near(actual, expected, label)
  assertions = assertions + 1
  if math.abs(actual - expected) > 0.000001 then
    error(
      string.format(
        "%s: expected %.8f, got %.8f",
        label,
        expected,
        actual
      ),
      2
    )
  end
end

local function sameFrame(actual, expected, label)
  near(actual.x, expected.x, label .. " x")
  near(actual.y, expected.y, label .. " y")
  near(actual.w, expected.w, label .. " width")
  near(actual.h, expected.h, label .. " height")
end

equal(logic.normalizeName("  Project Atlas  "), "Project Atlas", "trim workspace name")
local emptyName, emptyNameErr = logic.normalizeName("   ")
equal(emptyName, nil, "reject empty workspace name")
equal(emptyNameErr, "empty-name", "empty workspace name error")
local invalidName, invalidNameErr = logic.normalizeName(42)
equal(invalidName, nil, "reject non-string workspace name")
equal(invalidNameErr, "invalid-name", "non-string workspace name error")
local controlName, controlNameErr = logic.normalizeName("Project\nAtlas")
equal(controlName, nil, "reject control character in workspace name")
equal(controlNameErr, "invalid-name-characters", "control character name error")

local screen = { x = 100, y = 50, w = 1600, h = 1000 }
local frame = { x = 500, y = 300, w = 800, h = 500 }
local normalized = logic.normalizeFrame(frame, screen)
sameFrame(normalized, { x = 0.25, y = 0.25, w = 0.5, h = 0.5 }, "normalize frame")
sameFrame(logic.absoluteFrame(normalized, screen), frame, "round-trip frame")

local clamped = logic.absoluteFrame(
  { x = -0.1, y = 0.9, w = 1.2, h = 0.4 },
  screen
)
sameFrame(
  clamped,
  { x = 100, y = 650, w = 1600, h = 400 },
  "clamp restored frame to screen"
)

local invalidFrame, invalidFrameErr = logic.normalizeFrame(
  { x = 0, y = 0, w = 0, h = 100 },
  screen
)
equal(invalidFrame, nil, "reject zero-width source frame")
equal(invalidFrameErr, "invalid-frame-or-screen", "invalid source frame error")

local recipe, recipeErr = logic.buildRecipe(
  "Project Atlas",
  {
    {
      bundleID = "com.mitchellh.ghostty",
      appName = "Ghostty",
      frame = { x = 900, y = 50, w = 800, h = 1000 },
      screenFrame = screen,
    },
    {
      bundleID = "com.apple.Safari",
      appName = "Safari",
      frame = { x = 100, y = 50, w = 800, h = 1000 },
      screenFrame = screen,
    },
    {
      bundleID = "com.mitchellh.ghostty",
      appName = "Ghostty",
      frame = { x = 100, y = 50, w = 800, h = 1000 },
      screenFrame = screen,
    },
  },
  "2026-10-05T00:00:00Z"
)
equal(recipeErr, nil, "build recipe error")
equal(recipe.schemaVersion, 1, "recipe schema version")
equal(recipe.name, "Project Atlas", "recipe name")
equal(recipe.capturedAt, "2026-10-05T00:00:00Z", "recipe capture time")
equal(#recipe.windows, 3, "recipe window count")
equal(recipe.windows[1].bundleID, "com.apple.Safari", "sort apps by bundle ID")
equal(recipe.windows[1].ordinal, 1, "Safari slot ordinal")
equal(recipe.windows[2].bundleID, "com.mitchellh.ghostty", "first Ghostty bundle ID")
equal(recipe.windows[2].ordinal, 1, "left Ghostty slot ordinal")
near(recipe.windows[2].frame.x, 0, "left Ghostty normalized x")
equal(recipe.windows[3].ordinal, 2, "right Ghostty slot ordinal")
near(recipe.windows[3].frame.x, 0.5, "right Ghostty normalized x")
equal(recipe.windows[1].sourceIndex, nil, "do not persist capture source index")
equal(logic.validateRecipe(recipe), true, "validate built recipe")
equal(logic.applicationSummary(recipe), "Ghostty × 2, Safari", "application summary")

local noWindows, noWindowsErr = logic.buildRecipe(
  "Empty",
  {},
  "2026-10-05T00:00:00Z"
)
equal(noWindows, nil, "reject empty recipe")
equal(noWindowsErr, "no-windows", "empty recipe error")

local invalidRecipe = {
  schemaVersion = 1,
  name = "Broken",
  capturedAt = "2026-10-05T00:00:00Z",
  windows = {
    {
      bundleID = "com.example.App",
      appName = "Example",
      ordinal = 1,
      frame = { x = 0, y = 0, w = 0.5, h = 1 },
    },
    {
      bundleID = "com.example.App",
      appName = "Example",
      ordinal = 1,
      frame = { x = 0.5, y = 0, w = 0.5, h = 1 },
    },
  },
}
local duplicateValid, duplicateErr = logic.validateRecipe(invalidRecipe)
equal(duplicateValid, nil, "reject duplicate recipe slot")
equal(duplicateErr, "duplicate-recipe-slot", "duplicate recipe slot error")

local catalog = logic.newCatalog()
catalog.recipes[recipe.name] = recipe
equal(logic.validateCatalog(catalog), true, "validate recipe catalog")
local mismatchedCatalog = logic.newCatalog()
mismatchedCatalog.recipes["Other Name"] = recipe
local mismatchValid, mismatchErr = logic.validateCatalog(mismatchedCatalog)
equal(mismatchValid, nil, "reject catalog name mismatch")
equal(mismatchErr, "catalog-name-mismatch", "catalog name mismatch error")

local candidates = {
  {
    id = 31,
    bundleID = "com.mitchellh.ghostty",
    frame = { x = 0.52, y = 0, w = 0.48, h = 1 },
  },
  {
    id = 11,
    bundleID = "com.apple.Safari",
    frame = { x = 0.48, y = 0, w = 0.52, h = 1 },
  },
  {
    id = 21,
    bundleID = "com.mitchellh.ghostty",
    frame = { x = 0.02, y = 0, w = 0.48, h = 1 },
  },
  {
    id = 41,
    bundleID = "com.apple.finder",
    frame = { x = 0.25, y = 0.25, w = 0.5, h = 0.5 },
  },
}

local matches, matchErr = logic.matchWindows(recipe, candidates)
equal(matchErr, nil, "match windows error")
equal(#matches.assignments, 3, "matched window count")
equal(#matches.missing, 0, "no missing windows")
equal(#matches.extras, 1, "leave unmatched extra window")
equal(matches.extras[1].id, 41, "Finder remains extra")

local targetToCandidate = {}
for _, assignment in ipairs(matches.assignments) do
  targetToCandidate[assignment.target.bundleID .. ":" .. assignment.target.ordinal] =
    assignment.candidate.id
end
equal(targetToCandidate["com.apple.Safari:1"], 11, "match Safari by bundle ID")
equal(targetToCandidate["com.mitchellh.ghostty:1"], 21, "match left Ghostty by geometry")
equal(targetToCandidate["com.mitchellh.ghostty:2"], 31, "match right Ghostty by geometry")

local partialMatches = logic.matchWindows(recipe, {
  {
    id = 51,
    bundleID = "com.mitchellh.ghostty",
    frame = { x = 0.1, y = 0, w = 0.5, h = 1 },
  },
})
equal(#partialMatches.assignments, 1, "match available window")
equal(#partialMatches.missing, 2, "report missing windows")
equal(#partialMatches.extras, 0, "matched candidate is not extra")

local invalidMatches, invalidMatchErr = logic.matchWindows(recipe, {
  { bundleID = "com.apple.Safari", frame = { x = 0, y = 0, w = 0, h = 1 } },
})
equal(invalidMatches, nil, "reject invalid candidate")
equal(invalidMatchErr, "invalid-candidate-1", "invalid candidate error")

print(string.format("workspace_logic_spec: %d assertions passed", assertions))
