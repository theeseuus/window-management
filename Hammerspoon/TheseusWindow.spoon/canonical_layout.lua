-- Stateless canonical size and position helpers.
--
-- Frames are compared in the usable screen's normalized coordinate system so
-- the same rules work on every display. The only persistent window geometry
-- belongs to the window itself; these helpers do not keep per-window state.

local layout = {}

local EPSILON = 0.000001
local SIZE_ORDER = { "half", "quarter", "eighth", "sixteenth" }

local function slot(name, x, y, w, h)
  return { name = name, x = x, y = y, w = w, h = h }
end

local definitions = {
  half = {
    label = "1/2",
    slots = {
      slot("left", 0.00, 0.00, 0.50, 1.00),
      slot("centre", 0.25, 0.00, 0.50, 1.00),
      slot("right", 0.50, 0.00, 0.50, 1.00),
    },
  },
  quarter = {
    label = "1/4",
    -- Clockwise: top-left -> top-right -> bottom-right -> bottom-left.
    slots = {
      slot("top-left", 0.00, 0.00, 0.50, 0.50),
      slot("top-right", 0.50, 0.00, 0.50, 0.50),
      slot("bottom-right", 0.50, 0.50, 0.50, 0.50),
      slot("bottom-left", 0.00, 0.50, 0.50, 0.50),
    },
  },
}

local eighthSlots = {}
for column = 0, 3 do
  table.insert(eighthSlots, slot("top-" .. (column + 1), column / 4, 0.00, 0.25, 0.50))
end
for column = 3, 0, -1 do
  table.insert(eighthSlots, slot("bottom-" .. (column + 1), column / 4, 0.50, 0.25, 0.50))
end
definitions.eighth = {
  label = "1/8",
  -- A contiguous clockwise perimeter: top-left -> top-right -> bottom-right
  -- -> bottom-left. This is the established 4-by-2 order.
  slots = eighthSlots,
}

local sixteenthSlots = {}
for row = 0, 3 do
  for sequenceColumn = 0, 3 do
    -- Alternating each row makes every consecutive slot adjacent.
    local column = (row % 2 == 0) and sequenceColumn or (3 - sequenceColumn)
    table.insert(
      sixteenthSlots,
      slot(string.format("row-%d-column-%d", row + 1, column + 1), column / 4, row / 4, 0.25, 0.25)
    )
  end
end
definitions.sixteenth = {
  label = "1/16",
  -- A four-row serpentine: left-to-right, right-to-left, and so on.
  slots = sixteenthSlots,
}

local function usableScreen(screenFrame)
  return screenFrame
    and tonumber(screenFrame.w)
    and tonumber(screenFrame.h)
    and screenFrame.w > 0
    and screenFrame.h > 0
end

local function normaliseFrame(frame, screenFrame)
  if not frame or not usableScreen(screenFrame) then
    return nil, "invalid-frame-or-screen"
  end

  return {
    x = (frame.x - screenFrame.x) / screenFrame.w,
    y = (frame.y - screenFrame.y) / screenFrame.h,
    w = frame.w / screenFrame.w,
    h = frame.h / screenFrame.h,
    cx = (frame.x + frame.w / 2 - screenFrame.x) / screenFrame.w,
    cy = (frame.y + frame.h / 2 - screenFrame.y) / screenFrame.h,
  }
end

local function frameForSlot(slotDefinition, screenFrame)
  return {
    x = screenFrame.x + screenFrame.w * slotDefinition.x,
    y = screenFrame.y + screenFrame.h * slotDefinition.y,
    w = screenFrame.w * slotDefinition.w,
    h = screenFrame.h * slotDefinition.h,
  }
end

local function slotCentre(slotDefinition)
  return slotDefinition.x + slotDefinition.w / 2, slotDefinition.y + slotDefinition.h / 2
end

local function outwardTieBreak(normalisedFrame, slotDefinition)
  local slotX, slotY = slotCentre(slotDefinition)
  local score = 0
  local sourceX = normalisedFrame.cx - 0.5
  local sourceY = normalisedFrame.cy - 0.5

  -- When two finer slots are equally close, retain an outer edge already
  -- occupied by the source frame: a top-right quarter therefore becomes the
  -- top-right eighth rather than its inner neighbour.
  if math.abs(sourceX) > EPSILON then
    score = score + (slotX - 0.5) * (sourceX > 0 and 1 or -1)
  end
  if math.abs(sourceY) > EPSILON then
    score = score + (slotY - 0.5) * (sourceY > 0 and 1 or -1)
  end

  return score
end

function layout.label(sizeName)
  local definition = definitions[sizeName]
  return definition and definition.label or nil
end

function layout.nearestSize(frame, screenFrame)
  local normalisedFrame, err = normaliseFrame(frame, screenFrame)
  if not normalisedFrame then return nil, err end

  local nearestName, nearestIndex, nearestDistance
  for index, sizeName in ipairs(SIZE_ORDER) do
    local firstSlot = definitions[sizeName].slots[1]
    local widthDifference = normalisedFrame.w - firstSlot.w
    local heightDifference = normalisedFrame.h - firstSlot.h
    local distance = widthDifference * widthDifference + heightDifference * heightDifference

    if not nearestDistance or distance < nearestDistance - EPSILON then
      nearestName = sizeName
      nearestIndex = index
      nearestDistance = distance
    end
  end

  return nearestName, nearestIndex
end

function layout.nearestPosition(frame, screenFrame, sizeName)
  local normalisedFrame, err = normaliseFrame(frame, screenFrame)
  if not normalisedFrame then return nil, err end

  local definition = definitions[sizeName]
  if not definition then return nil, "unknown-size" end

  local nearestIndex, nearestDistance, nearestOutwardScore
  for index, slotDefinition in ipairs(definition.slots) do
    local slotX, slotY = slotCentre(slotDefinition)
    local differenceX = normalisedFrame.cx - slotX
    local differenceY = normalisedFrame.cy - slotY
    local distance = differenceX * differenceX + differenceY * differenceY
    local outwardScore = outwardTieBreak(normalisedFrame, slotDefinition)

    if not nearestDistance
      or distance < nearestDistance - EPSILON
      or (
        math.abs(distance - nearestDistance) <= EPSILON
        and outwardScore > nearestOutwardScore + EPSILON
      ) then
      nearestIndex = index
      nearestDistance = distance
      nearestOutwardScore = outwardScore
    end
  end

  return nearestIndex
end

local function cycleIndex(currentIndex, count, step)
  local direction = step == -1 and -1 or 1
  return ((currentIndex - 1 + direction) % count) + 1
end

function layout.sizeCycle(frame, screenFrame, step)
  local currentName, currentIndex = layout.nearestSize(frame, screenFrame)
  if not currentName then return nil, currentIndex end

  local nextIndex = cycleIndex(currentIndex, #SIZE_ORDER, step)
  local nextName = SIZE_ORDER[nextIndex]
  local nextPosition, err = layout.nearestPosition(frame, screenFrame, nextName)
  if not nextPosition then return nil, err end

  local definition = definitions[nextName]
  return frameForSlot(definition.slots[nextPosition], screenFrame), nextName, nextPosition, #definition.slots
end

function layout.positionCycle(frame, screenFrame, step)
  local sizeName, err = layout.nearestSize(frame, screenFrame)
  if not sizeName then return nil, err end

  local currentPosition, positionErr = layout.nearestPosition(frame, screenFrame, sizeName)
  if not currentPosition then return nil, positionErr end

  local definition = definitions[sizeName]
  local nextPosition = cycleIndex(currentPosition, #definition.slots, step)
  return frameForSlot(definition.slots[nextPosition], screenFrame), sizeName, nextPosition, #definition.slots
end

return layout
