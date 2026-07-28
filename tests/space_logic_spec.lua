local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/space_logic.lua"
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

local function sameList(actual, expected, label)
  equal(#actual, #expected, label .. " length")
  for index, value in ipairs(expected) do
    equal(actual[index], value, label .. " item " .. index)
  end
end

equal(logic.indicatorTitle(1), "[1]", "first Space indicator")
equal(logic.indicatorTitle("—"), "[—]", "non-user Space indicator")
equal(logic.indicatorTitle(), "[?]", "unavailable Space indicator")

local types = {
  [101] = "user",
  [102] = "fullscreen",
  [103] = "user",
  [104] = "user"
}

local userSpaces, filterErr = logic.userSpaces(
  { 101, 102, 103, 104 },
  function(spaceID)
    return types[spaceID]
  end
)
equal(filterErr, nil, "filter error")
sameList(userSpaces, { 101, 103, 104 }, "ordered user Spaces")

local previous, previousErr, previousOrdinal = logic.adjacent(userSpaces, 103, -1)
equal(previous, 101, "previous Space")
equal(previousErr, nil, "previous error")
equal(previousOrdinal, 1, "previous ordinal")

local nextSpace, nextErr, nextOrdinal = logic.adjacent(userSpaces, 103, 1)
equal(nextSpace, 104, "next Space")
equal(nextErr, nil, "next error")
equal(nextOrdinal, 3, "next ordinal")

local beforeFirst, beforeFirstErr = logic.adjacent(userSpaces, 101, -1)
equal(beforeFirst, nil, "first boundary destination")
equal(beforeFirstErr, "boundary", "first boundary error")

local afterLast, afterLastErr = logic.adjacent(userSpaces, 104, 1)
equal(afterLast, nil, "last boundary destination")
equal(afterLastErr, "boundary", "last boundary error")

local missing, missingErr = logic.adjacent(userSpaces, 999, 1)
equal(missing, nil, "missing current destination")
equal(missingErr, "current-not-found", "missing current error")

local invalid, invalidErr = logic.adjacent(userSpaces, 103, 0)
equal(invalid, nil, "invalid direction destination")
equal(invalidErr, "invalid-direction", "invalid direction error")

local ordinal, count = logic.ordinal(userSpaces, 103)
equal(ordinal, 2, "active ordinal")
equal(count, 3, "active user Space count")
equal(logic.contains(userSpaces, 104), true, "contains destination")
equal(logic.contains(userSpaces, 102), false, "does not contain full-screen Space")

local failedSpaces, failedErr = logic.userSpaces({ 101 }, function()
  return nil, "type lookup failed"
end)
equal(failedSpaces, nil, "type failure result")
equal(failedErr, "type lookup failed", "type failure error")

print(string.format("space_logic_spec: %d assertions passed", assertions))
