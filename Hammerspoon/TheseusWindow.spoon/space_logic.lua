-- Pure helpers for reasoning about ordered native macOS Spaces.
-- This module deliberately has no Hammerspoon dependencies so its boundary
-- behaviour can be tested without moving a live window or changing Space.

local M = {}

function M.contains(values, needle)
  for _, value in ipairs(values or {}) do
    if value == needle then
      return true
    end
  end
  return false
end

function M.userSpaces(orderedSpaces, typeForSpace)
  if type(orderedSpaces) ~= "table" then
    return nil, "ordered Spaces must be a table"
  end
  if type(typeForSpace) ~= "function" then
    return nil, "typeForSpace must be a function"
  end

  local result = {}
  for _, spaceID in ipairs(orderedSpaces) do
    local spaceType, err = typeForSpace(spaceID)
    if not spaceType then
      return nil, err or ("could not determine type for Space " .. tostring(spaceID))
    end
    if spaceType == "user" then
      table.insert(result, spaceID)
    end
  end
  return result
end

function M.ordinal(orderedSpaces, currentSpace)
  for index, spaceID in ipairs(orderedSpaces or {}) do
    if spaceID == currentSpace then
      return index, #orderedSpaces
    end
  end
  return nil, #(orderedSpaces or {})
end

function M.adjacent(orderedSpaces, currentSpace, direction)
  if direction ~= -1 and direction ~= 1 then
    return nil, "invalid-direction"
  end

  local currentIndex = M.ordinal(orderedSpaces, currentSpace)
  if not currentIndex then
    return nil, "current-not-found"
  end

  local destinationIndex = currentIndex + direction
  if destinationIndex < 1 or destinationIndex > #orderedSpaces then
    return nil, "boundary"
  end

  return orderedSpaces[destinationIndex], nil, destinationIndex
end

return M
