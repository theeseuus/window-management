local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")
local logic = dofile(
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/cycle_logic.lua"
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

equal(logic.nextIndex(nil, 4, 1), 1, "fresh forward cycle")
equal(logic.nextIndex(nil, 4, -1), 4, "fresh reverse cycle")
equal(logic.nextIndex(1, 4, 1), 2, "forward cycle")
equal(logic.nextIndex(4, 4, 1), 1, "forward wrap")
equal(logic.nextIndex(4, 4, -1), 3, "reverse cycle")
equal(logic.nextIndex(1, 4, -1), 4, "reverse wrap")

local invalidCount, invalidCountErr = logic.nextIndex(nil, 0, 1)
equal(invalidCount, nil, "invalid count result")
equal(invalidCountErr, "invalid-count", "invalid count error")

local invalidStep, invalidStepErr = logic.nextIndex(nil, 4, 0)
equal(invalidStep, nil, "invalid step result")
equal(invalidStepErr, "invalid-step", "invalid step error")

print(string.format("cycle_logic_spec: %d assertions passed", assertions))
