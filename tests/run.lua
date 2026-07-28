local testPath = debug.getinfo(1, "S").source:match("^@(.*/)")
local repositoryRoot = testPath:match("^(.*)/tests/$")

local luaFiles = {
  repositoryRoot .. "/Hammerspoon/init.lua",
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/init.lua",
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/cycle_logic.lua",
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/native_space_move.lua",
  repositoryRoot .. "/Hammerspoon/TheseusWindow.spoon/space_logic.lua",
  repositoryRoot .. "/tests/cycle_logic_spec.lua",
  repositoryRoot .. "/tests/space_logic_spec.lua"
}

for _, path in ipairs(luaFiles) do
  local chunk, syntaxErr = loadfile(path)
  if not chunk then
    error("Lua syntax validation failed for " .. path .. ": " .. tostring(syntaxErr))
  end
end

print(string.format("syntax: %d Lua files compiled", #luaFiles))
dofile(repositoryRoot .. "/tests/cycle_logic_spec.lua")
dofile(repositoryRoot .. "/tests/space_logic_spec.lua")
print("validation: passed")
