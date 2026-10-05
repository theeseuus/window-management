local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/spatial_focus_logic.lua"
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

local function candidate(name, x, y, w, h)
  return {
    name = name,
    frame = { x = x, y = y, w = w, h = h },
  }
end

local current = { x = 100, y = 100, w = 100, h = 100 }
local left = candidate("left", 20, 110, 70, 80)
local right = candidate("right", 210, 110, 70, 80)
local up = candidate("up", 110, 20, 80, 70)
local down = candidate("down", 110, 210, 80, 70)

equal(logic.nearest(current, { right, left }, "left"), left, "select left candidate")
equal(logic.nearest(current, { left, right }, "right"), right, "select right candidate")
equal(logic.nearest(current, { down, up }, "up"), up, "select up candidate")
equal(logic.nearest(current, { up, down }, "down"), down, "select down candidate")

local diagonalLeft = candidate("diagonal-left", 20, 0, 70, 50)
equal(
  logic.nearest(current, { diagonalLeft, left }, "left"),
  left,
  "reject diagonal without vertical overlap"
)

local touchingLeft = candidate("touching-left", 20, 0, 70, 100)
equal(
  logic.nearest(current, { touchingLeft }, "left"),
  nil,
  "reject candidate touching perpendicular boundary"
)

local gapPriority = candidate("gap-priority", 15, 140, 80, 20)
local alignedButFarther = candidate("aligned-farther", 0, 110, 90, 80)
equal(
  logic.nearest(current, { alignedButFarther, gapPriority }, "left"),
  gapPriority,
  "edge gap outranks cross-axis alignment"
)

local crossNear = candidate("cross-near", 0, 110, 90, 80)
local crossFar = candidate("cross-far", 0, 100, 90, 50)
equal(
  logic.nearest(current, { crossFar, crossNear }, "left"),
  crossNear,
  "cross-axis distance breaks equal gaps"
)

local overlapSmall = candidate("overlap-small", 0, 130, 90, 40)
local overlapLarge = candidate("overlap-large", 0, 110, 90, 80)
equal(
  logic.nearest(current, { overlapSmall, overlapLarge }, "left"),
  overlapLarge,
  "larger overlap breaks equal gap and centre distance"
)

local directionNear = candidate("direction-near", 40, 100, 80, 100)
local directionFar = candidate("direction-far", 0, 100, 120, 100)
equal(
  logic.nearest(current, { directionFar, directionNear }, "left"),
  directionNear,
  "direction distance breaks remaining ties"
)

local exactTieFirst = candidate("tie-first", 0, 100, 90, 100)
local exactTieSecond = candidate("tie-second", 0, 100, 90, 100)
equal(
  logic.nearest(current, { exactTieFirst, exactTieSecond }, "left"),
  exactTieFirst,
  "exact ties retain candidate order"
)

local invalidWidth = candidate("invalid-width", 20, 100, 0, 100)
local invalidType = { name = "invalid-type", frame = { x = "20", y = 100, w = 70, h = 100 } }
equal(
  logic.nearest(current, { invalidWidth, invalidType, left }, "left"),
  left,
  "skip invalid candidate frames"
)

equal(logic.nearest(nil, { left }, "left"), nil, "reject missing current frame")
equal(
  logic.nearest({ x = 100, y = 100, w = 0, h = 100 }, { left }, "left"),
  nil,
  "reject invalid current frame"
)
equal(logic.nearest(current, nil, "left"), nil, "reject missing candidate list")
equal(logic.nearest(current, { left }, "diagonal"), nil, "reject unsupported direction")
equal(logic.nearest(current, {}, "left"), nil, "empty candidates have no result")

print(string.format("spatial_focus_logic_spec: %d assertions passed", assertions))
