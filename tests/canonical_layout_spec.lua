local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/canonical_layout.lua"
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

local function sameFrame(actual, expected, label)
  equal(actual.x, expected.x, label .. " x")
  equal(actual.y, expected.y, label .. " y")
  equal(actual.w, expected.w, label .. " width")
  equal(actual.h, expected.h, label .. " height")
end

local screen = { x = 100, y = 50, w = 1600, h = 1000 }
local halfLeft = { x = 100, y = 50, w = 800, h = 1000 }
local halfCentre = { x = 500, y = 50, w = 800, h = 1000 }
local halfRight = { x = 900, y = 50, w = 800, h = 1000 }
local quarterTopLeft = { x = 100, y = 50, w = 800, h = 500 }
local quarterTopRight = { x = 900, y = 50, w = 800, h = 500 }
local quarterBottomLeft = { x = 100, y = 550, w = 800, h = 500 }
local eighthTopRight = { x = 1300, y = 50, w = 400, h = 500 }
local eighthBottomLeft = { x = 100, y = 550, w = 400, h = 500 }
local sixteenthTopLeft = { x = 100, y = 50, w = 400, h = 250 }
local sixteenthBottomLeft = { x = 100, y = 800, w = 400, h = 250 }

equal(logic.label("half"), "1/2", "half label")
equal(logic.label("quarter"), "1/4", "quarter label")
equal(logic.label("eighth"), "1/8", "eighth label")
equal(logic.label("sixteenth"), "1/16", "sixteenth label")
equal(logic.label("unknown"), nil, "unknown label")

local exactSizes = {
  { frame = halfLeft, name = "half", index = 1 },
  { frame = quarterTopLeft, name = "quarter", index = 2 },
  { frame = eighthTopRight, name = "eighth", index = 3 },
  { frame = sixteenthTopLeft, name = "sixteenth", index = 4 },
}
for _, example in ipairs(exactSizes) do
  local name, index = logic.nearestSize(example.frame, screen)
  equal(name, example.name, example.name .. " exact size")
  equal(index, example.index, example.name .. " size index")
end

local invalidSize, invalidSizeErr = logic.nearestSize(nil, screen)
equal(invalidSize, nil, "nil frame size result")
equal(invalidSizeErr, "invalid-frame-or-screen", "nil frame size error")

local invalidScreenSize, invalidScreenSizeErr = logic.nearestSize(
  halfLeft,
  { x = 0, y = 0, w = 0, h = 1000 }
)
equal(invalidScreenSize, nil, "invalid screen size result")
equal(invalidScreenSizeErr, "invalid-frame-or-screen", "invalid screen size error")

equal(logic.nearestPosition(quarterTopRight, screen, "quarter"), 2, "quarter position")

local unknownPosition, unknownPositionErr = logic.nearestPosition(halfLeft, screen, "unknown")
equal(unknownPosition, nil, "unknown position result")
equal(unknownPositionErr, "unknown-size", "unknown position error")

local quarterFrame, quarterName, quarterPosition, quarterCount =
  logic.sizeCycle(halfLeft, screen, 1)
sameFrame(quarterFrame, quarterTopLeft, "half to quarter")
equal(quarterName, "quarter", "half to quarter name")
equal(quarterPosition, 1, "half to quarter position")
equal(quarterCount, 4, "half to quarter count")

local eighthFrame, eighthName, eighthPosition, eighthCount =
  logic.sizeCycle(quarterTopRight, screen, 1)
sameFrame(eighthFrame, eighthTopRight, "top-right quarter to outward eighth")
equal(eighthName, "eighth", "quarter to eighth name")
equal(eighthPosition, 4, "quarter to outward eighth position")
equal(eighthCount, 8, "quarter to eighth count")

local reverseSizeFrame, reverseSizeName, _, reverseSizeCount =
  logic.sizeCycle(halfLeft, screen, -1)
equal(reverseSizeName, "sixteenth", "reverse size wraps to sixteenth")
equal(reverseSizeFrame.w, 400, "reverse size width")
equal(reverseSizeFrame.h, 250, "reverse size height")
equal(reverseSizeCount, 16, "reverse size count")

local wrappedSizeFrame, wrappedSizeName, wrappedSizePosition, wrappedSizeCount =
  logic.sizeCycle(sixteenthTopLeft, screen, 1)
sameFrame(wrappedSizeFrame, halfLeft, "sixteenth to half wrap")
equal(wrappedSizeName, "half", "sixteenth to half name")
equal(wrappedSizePosition, 1, "sixteenth to half position")
equal(wrappedSizeCount, 3, "sixteenth to half count")

local halfForward, halfForwardName, halfForwardPosition, halfForwardCount =
  logic.positionCycle(halfLeft, screen, 1)
sameFrame(halfForward, halfCentre, "half position forward")
equal(halfForwardName, "half", "half forward name")
equal(halfForwardPosition, 2, "half forward position")
equal(halfForwardCount, 3, "half forward count")

local halfReverse, _, halfReversePosition = logic.positionCycle(halfLeft, screen, -1)
sameFrame(halfReverse, halfRight, "half position reverse wrap")
equal(halfReversePosition, 3, "half reverse position")

local quarterForward, _, quarterForwardPosition = logic.positionCycle(quarterTopLeft, screen, 1)
sameFrame(quarterForward, quarterTopRight, "quarter position forward")
equal(quarterForwardPosition, 2, "quarter forward position")

local quarterReverse, _, quarterReversePosition = logic.positionCycle(quarterTopLeft, screen, -1)
sameFrame(quarterReverse, quarterBottomLeft, "quarter position reverse wrap")
equal(quarterReversePosition, 4, "quarter reverse position")

local eighthReverse, _, eighthReversePosition = logic.positionCycle(
  { x = 100, y = 50, w = 400, h = 500 },
  screen,
  -1
)
sameFrame(eighthReverse, eighthBottomLeft, "eighth position reverse wrap")
equal(eighthReversePosition, 8, "eighth reverse position")

local sixteenthReverse, _, sixteenthReversePosition =
  logic.positionCycle(sixteenthTopLeft, screen, -1)
sameFrame(sixteenthReverse, sixteenthBottomLeft, "sixteenth position reverse wrap")
equal(sixteenthReversePosition, 16, "sixteenth reverse position")

local manualForward, manualName, manualPosition = logic.positionCycle(
  { x = 110, y = 60, w = 780, h = 490 },
  screen,
  1
)
sameFrame(manualForward, quarterTopRight, "manual frame canonical position")
equal(manualName, "quarter", "manual frame nearest size")
equal(manualPosition, 2, "manual frame next position")

local invalidCycle, invalidCycleErr = logic.positionCycle(
  halfLeft,
  { x = 0, y = 0, w = 1000, h = 0 },
  1
)
equal(invalidCycle, nil, "invalid position cycle result")
equal(invalidCycleErr, "invalid-frame-or-screen", "invalid position cycle error")

print(string.format("canonical_layout_spec: %d assertions passed", assertions))
