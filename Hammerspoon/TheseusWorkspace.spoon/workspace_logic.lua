local logic = {}

logic.schemaVersion = 1

local function isFiniteNumber(value)
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
end

local function validFrame(frame)
  return type(frame) == "table"
    and isFiniteNumber(frame.x)
    and isFiniteNumber(frame.y)
    and isFiniteNumber(frame.w)
    and isFiniteNumber(frame.h)
    and frame.w > 0
    and frame.h > 0
end

local function frameCost(left, right)
  local leftCentreX = left.x + (left.w / 2)
  local leftCentreY = left.y + (left.h / 2)
  local rightCentreX = right.x + (right.w / 2)
  local rightCentreY = right.y + (right.h / 2)
  local dx = leftCentreX - rightCentreX
  local dy = leftCentreY - rightCentreY
  local dw = left.w - right.w
  local dh = left.h - right.h
  return (dx * dx) + (dy * dy) + (dw * dw) + (dh * dh)
end

local function frameComesBefore(left, right)
  if left.frame.y ~= right.frame.y then
    return left.frame.y < right.frame.y
  end
  if left.frame.x ~= right.frame.x then
    return left.frame.x < right.frame.x
  end
  if left.frame.h ~= right.frame.h then
    return left.frame.h < right.frame.h
  end
  if left.frame.w ~= right.frame.w then
    return left.frame.w < right.frame.w
  end
  return left.sourceIndex < right.sourceIndex
end

function logic.normalizeName(value)
  if type(value) ~= "string" then
    return nil, "invalid-name"
  end

  local name = value:match("^%s*(.-)%s*$")
  if name == "" then
    return nil, "empty-name"
  end
  if name:find("[%c]") then
    return nil, "invalid-name-characters"
  end
  if #name > 80 then
    return nil, "name-too-long"
  end
  return name
end

function logic.normalizeFrame(frame, screenFrame)
  if not validFrame(frame) or not validFrame(screenFrame) then
    return nil, "invalid-frame-or-screen"
  end

  return {
    x = (frame.x - screenFrame.x) / screenFrame.w,
    y = (frame.y - screenFrame.y) / screenFrame.h,
    w = frame.w / screenFrame.w,
    h = frame.h / screenFrame.h,
  }
end

function logic.absoluteFrame(normalizedFrame, screenFrame)
  if not validFrame(normalizedFrame) or not validFrame(screenFrame) then
    return nil, "invalid-frame-or-screen"
  end

  local width = math.max(1, math.min(screenFrame.w, normalizedFrame.w * screenFrame.w))
  local height = math.max(1, math.min(screenFrame.h, normalizedFrame.h * screenFrame.h))
  local x = screenFrame.x + (normalizedFrame.x * screenFrame.w)
  local y = screenFrame.y + (normalizedFrame.y * screenFrame.h)

  x = math.max(screenFrame.x, math.min(screenFrame.x + screenFrame.w - width, x))
  y = math.max(screenFrame.y, math.min(screenFrame.y + screenFrame.h - height, y))

  return { x = x, y = y, w = width, h = height }
end

function logic.buildRecipe(name, records, capturedAt)
  local normalizedName, nameErr = logic.normalizeName(name)
  if not normalizedName then
    return nil, nameErr
  end
  if type(capturedAt) ~= "string" or capturedAt == "" then
    return nil, "invalid-captured-at"
  end
  if type(records) ~= "table" or #records == 0 then
    return nil, "no-windows"
  end

  local windows = {}
  for index, record in ipairs(records) do
    if type(record) ~= "table"
      or type(record.bundleID) ~= "string"
      or record.bundleID == "" then
      return nil, "invalid-window-identity-" .. tostring(index)
    end

    local frame, frameErr = logic.normalizeFrame(record.frame, record.screenFrame)
    if not frame then
      return nil, frameErr .. "-" .. tostring(index)
    end

    local appName = record.appName
    if type(appName) ~= "string" or appName == "" then
      appName = record.bundleID
    end

    table.insert(windows, {
      bundleID = record.bundleID,
      appName = appName,
      frame = frame,
      sourceIndex = index,
    })
  end

  table.sort(windows, function(left, right)
    if left.bundleID ~= right.bundleID then
      return left.bundleID < right.bundleID
    end
    return frameComesBefore(left, right)
  end)

  local counts = {}
  for _, window in ipairs(windows) do
    counts[window.bundleID] = (counts[window.bundleID] or 0) + 1
    window.ordinal = counts[window.bundleID]
    window.sourceIndex = nil
  end

  return {
    schemaVersion = logic.schemaVersion,
    name = normalizedName,
    capturedAt = capturedAt,
    windows = windows,
  }
end

function logic.validateRecipe(recipe)
  if type(recipe) ~= "table" then
    return nil, "invalid-recipe"
  end
  if recipe.schemaVersion ~= logic.schemaVersion then
    return nil, "unsupported-recipe-version"
  end

  local normalizedName = logic.normalizeName(recipe.name)
  if not normalizedName or normalizedName ~= recipe.name then
    return nil, "invalid-recipe-name"
  end
  if type(recipe.capturedAt) ~= "string" or recipe.capturedAt == "" then
    return nil, "invalid-recipe-captured-at"
  end
  if type(recipe.windows) ~= "table" or #recipe.windows == 0 then
    return nil, "invalid-recipe-windows"
  end

  local seenSlots = {}
  for index, window in ipairs(recipe.windows) do
    if type(window) ~= "table"
      or type(window.bundleID) ~= "string"
      or window.bundleID == ""
      or type(window.appName) ~= "string"
      or window.appName == ""
      or type(window.ordinal) ~= "number"
      or window.ordinal < 1
      or window.ordinal % 1 ~= 0
      or not validFrame(window.frame) then
      return nil, "invalid-recipe-window-" .. tostring(index)
    end

    local slot = window.bundleID .. "\0" .. tostring(window.ordinal)
    if seenSlots[slot] then
      return nil, "duplicate-recipe-slot"
    end
    seenSlots[slot] = true
  end

  return true
end

function logic.newCatalog()
  return {
    schemaVersion = logic.schemaVersion,
    recipes = {},
  }
end

function logic.validateCatalog(catalog)
  if type(catalog) ~= "table" then
    return nil, "invalid-catalog"
  end
  if catalog.schemaVersion ~= logic.schemaVersion then
    return nil, "unsupported-catalog-version"
  end
  if type(catalog.recipes) ~= "table" then
    return nil, "invalid-catalog-recipes"
  end

  for name, recipe in pairs(catalog.recipes) do
    local normalizedName = logic.normalizeName(name)
    if not normalizedName or normalizedName ~= name then
      return nil, "invalid-catalog-name"
    end
    local valid, recipeErr = logic.validateRecipe(recipe)
    if not valid then
      return nil, recipeErr
    end
    if recipe.name ~= name then
      return nil, "catalog-name-mismatch"
    end
  end

  return true
end

function logic.applicationSummary(recipe)
  local valid, recipeErr = logic.validateRecipe(recipe)
  if not valid then
    return nil, recipeErr
  end

  local apps = {}
  for _, window in ipairs(recipe.windows) do
    local app = apps[window.bundleID]
    if not app then
      app = { name = window.appName, count = 0 }
      apps[window.bundleID] = app
    end
    app.count = app.count + 1
  end

  local labels = {}
  for _, app in pairs(apps) do
    local label = app.name
    if app.count > 1 then
      label = string.format("%s × %d", label, app.count)
    end
    table.insert(labels, label)
  end
  table.sort(labels, function(left, right)
    return left:lower() < right:lower()
  end)
  return table.concat(labels, ", ")
end

function logic.matchWindows(recipe, candidates)
  local valid, recipeErr = logic.validateRecipe(recipe)
  if not valid then
    return nil, recipeErr
  end
  if type(candidates) ~= "table" then
    return nil, "invalid-candidates"
  end

  local orderedCandidates = {}
  for index, candidate in ipairs(candidates) do
    if type(candidate) ~= "table"
      or type(candidate.bundleID) ~= "string"
      or candidate.bundleID == ""
      or not validFrame(candidate.frame) then
      return nil, "invalid-candidate-" .. tostring(index)
    end
    table.insert(orderedCandidates, {
      candidate = candidate,
      sourceIndex = index,
    })
  end

  table.sort(orderedCandidates, function(left, right)
    local leftCandidate = left.candidate
    local rightCandidate = right.candidate
    if leftCandidate.bundleID ~= rightCandidate.bundleID then
      return leftCandidate.bundleID < rightCandidate.bundleID
    end
    local leftFrame = {
      frame = leftCandidate.frame,
      sourceIndex = left.sourceIndex,
    }
    local rightFrame = {
      frame = rightCandidate.frame,
      sourceIndex = right.sourceIndex,
    }
    return frameComesBefore(leftFrame, rightFrame)
  end)

  local assignments = {}
  local missing = {}
  local used = {}

  for _, target in ipairs(recipe.windows) do
    local bestIndex
    local bestCost
    for index, entry in ipairs(orderedCandidates) do
      local candidate = entry.candidate
      if not used[index] and candidate.bundleID == target.bundleID then
        local cost = frameCost(target.frame, candidate.frame)
        if bestCost == nil or cost < bestCost then
          bestIndex = index
          bestCost = cost
        end
      end
    end

    if bestIndex then
      used[bestIndex] = true
      table.insert(assignments, {
        target = target,
        candidate = orderedCandidates[bestIndex].candidate,
      })
    else
      table.insert(missing, target)
    end
  end

  local extras = {}
  for index, entry in ipairs(orderedCandidates) do
    if not used[index] then
      table.insert(extras, entry.candidate)
    end
  end

  return {
    assignments = assignments,
    missing = missing,
    extras = extras,
  }
end

return logic
