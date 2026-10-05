local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/geometry_logic.lua"
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

local screen = { x = 100, y = 30, w = 1600, h = 900 }

local topQuarter = logic.centerHorizontally(
  { x = 100, y = 30, w = 800, h = 450 },
  screen
)
equal(topQuarter.x, 500, "top quarter centered x")
equal(topQuarter.y, 30, "top quarter preserves y")
equal(topQuarter.w, 800, "top quarter preserves width")
equal(topQuarter.h, 450, "top quarter preserves height")

local bottomQuarter = logic.centerHorizontally(
  { x = 900, y = 480, w = 800, h = 450 },
  screen
)
equal(bottomQuarter.x, 500, "bottom quarter centered x")
equal(bottomQuarter.y, 480, "bottom quarter preserves y")
equal(bottomQuarter.w, 800, "bottom quarter preserves width")
equal(bottomQuarter.h, 450, "bottom quarter preserves height")

local eighth = logic.centerHorizontally(
  { x = 100, y = 30, w = 400, h = 450 },
  screen
)
equal(eighth.x, 700, "eighth centered x")
equal(eighth.y, 30, "eighth preserves y")
equal(eighth.w, 400, "eighth preserves width")
equal(eighth.h, 450, "eighth preserves height")

local custom = logic.centerHorizontally(
  { x = 0, y = 211, w = 641, h = 377 },
  { x = -1920, y = 25, w = 1920, h = 1055 }
)
equal(custom.x, -1280.5, "custom frame centered on offset screen")
equal(custom.y, 211, "custom frame preserves y")
equal(custom.w, 641, "custom frame preserves width")
equal(custom.h, 377, "custom frame preserves height")

print(string.format("geometry_logic_spec: %d assertions passed", assertions))
