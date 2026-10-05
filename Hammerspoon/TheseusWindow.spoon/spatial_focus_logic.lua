-- Axis-aligned directional window selection.
--
-- A candidate must overlap the focused window on the perpendicular axis:
-- left/right require vertical overlap; up/down require horizontal overlap.
-- This keeps directional focus in the same visual row or column instead of
-- allowing a diagonal window to win through angle-based scoring.

local spatialFocus = {}

local EPSILON = 0.000001

local function validFrame(frame)
  return frame
    and type(frame.x) == "number"
    and type(frame.y) == "number"
    and type(frame.w) == "number"
    and type(frame.h) == "number"
    and frame.w > EPSILON
    and frame.h > EPSILON
end

local function centreX(frame)
  return frame.x + frame.w / 2
end

local function centreY(frame)
  return frame.y + frame.h / 2
end

local function overlap(startA, lengthA, startB, lengthB)
  return math.min(startA + lengthA, startB + lengthB) - math.max(startA, startB)
end

local function candidateScore(current, candidate, direction)
  local frame = candidate and candidate.frame
  if not validFrame(frame) then return nil end

  if direction == "left" then
    if centreX(frame) >= centreX(current) - EPSILON then return nil end
    local verticalOverlap = overlap(current.y, current.h, frame.y, frame.h)
    if verticalOverlap <= EPSILON then return nil end
    return {
      gap = math.max(0, current.x - (frame.x + frame.w)),
      crossDistance = math.abs(centreY(current) - centreY(frame)),
      overlap = verticalOverlap,
      directionDistance = centreX(current) - centreX(frame),
    }
  end

  if direction == "right" then
    if centreX(frame) <= centreX(current) + EPSILON then return nil end
    local verticalOverlap = overlap(current.y, current.h, frame.y, frame.h)
    if verticalOverlap <= EPSILON then return nil end
    return {
      gap = math.max(0, frame.x - (current.x + current.w)),
      crossDistance = math.abs(centreY(current) - centreY(frame)),
      overlap = verticalOverlap,
      directionDistance = centreX(frame) - centreX(current),
    }
  end

  if direction == "up" then
    if centreY(frame) >= centreY(current) - EPSILON then return nil end
    local horizontalOverlap = overlap(current.x, current.w, frame.x, frame.w)
    if horizontalOverlap <= EPSILON then return nil end
    return {
      gap = math.max(0, current.y - (frame.y + frame.h)),
      crossDistance = math.abs(centreX(current) - centreX(frame)),
      overlap = horizontalOverlap,
      directionDistance = centreY(current) - centreY(frame),
    }
  end

  if direction == "down" then
    if centreY(frame) <= centreY(current) + EPSILON then return nil end
    local horizontalOverlap = overlap(current.x, current.w, frame.x, frame.w)
    if horizontalOverlap <= EPSILON then return nil end
    return {
      gap = math.max(0, frame.y - (current.y + current.h)),
      crossDistance = math.abs(centreX(current) - centreX(frame)),
      overlap = horizontalOverlap,
      directionDistance = centreY(frame) - centreY(current),
    }
  end

  return nil
end

local function scoreIsBetter(candidate, incumbent)
  if candidate.gap < incumbent.gap - EPSILON then return true end
  if candidate.gap > incumbent.gap + EPSILON then return false end

  if candidate.crossDistance < incumbent.crossDistance - EPSILON then return true end
  if candidate.crossDistance > incumbent.crossDistance + EPSILON then return false end

  if candidate.overlap > incumbent.overlap + EPSILON then return true end
  if candidate.overlap < incumbent.overlap - EPSILON then return false end

  return candidate.directionDistance < incumbent.directionDistance - EPSILON
end

function spatialFocus.nearest(currentFrame, candidates, direction)
  if not validFrame(currentFrame) or type(candidates) ~= "table" then return nil end

  local bestCandidate, bestScore
  for _, candidate in ipairs(candidates) do
    local score = candidateScore(currentFrame, candidate, direction)
    if score and (not bestScore or scoreIsBetter(score, bestScore)) then
      bestCandidate = candidate
      bestScore = score
    end
  end

  return bestCandidate
end

return spatialFocus
