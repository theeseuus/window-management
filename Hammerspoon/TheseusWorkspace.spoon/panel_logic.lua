-- Plain display models: no window handles, titles, paths, or persisted artwork.
local logic = {}

function logic.copy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, item in pairs(value) do copy[key] = logic.copy(item) end
  return copy
end

function logic.sameRecipe(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not logic.sameRecipe(value, right[key]) then return false end
  end
  for key in pairs(right) do if left[key] == nil then return false end end
  return true
end

function logic.describe(recipe)
  local groups, rectangles = {}, {}
  for _, slot in ipairs(recipe.windows) do
    local name = slot.appName
    groups[name] = (groups[name] or 0) + 1
    -- Match the placement engine's screen clamping without changing the recipe.
    local width, height = math.min(1, slot.frame.w), math.min(1, slot.frame.h)
    table.insert(rectangles, {
      x = math.max(0, math.min(1 - width, slot.frame.x)),
      y = math.max(0, math.min(1 - height, slot.frame.y)),
      w = width, h = height, appName = name, ordinal = slot.ordinal,
    })
  end
  local names = {}
  for name in pairs(groups) do table.insert(names, name) end
  table.sort(names)
  local applications = {}
  for _, name in ipairs(names) do
    table.insert(applications, name .. (groups[name] > 1 and " × " .. groups[name] or ""))
  end
  return {
    name = recipe.name, windowCount = #recipe.windows,
    applications = applications, summary = table.concat(applications, ", "),
    rectangles = rectangles,
  }
end

function logic.entries(catalog)
  local entries = {}
  for _, recipe in pairs(catalog.recipes) do table.insert(entries, logic.describe(recipe)) end
  table.sort(entries, function(left, right)
    local a, b = left.name:lower(), right.name:lower()
    return a == b and left.name < right.name or a < b
  end)
  return entries
end

return logic
