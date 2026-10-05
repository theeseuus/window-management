-- Sequential, bounded creation followed by verified placement. The injected
-- operations make the lifecycle testable without touching the desktop.
local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local logic = dofile(sourcePath .. "workspace_logic.lua")
local establish = {}

function establish.start(recipe, options, complete)
  local report = {
    name = recipe.name, requested = #recipe.windows, applied = 0, created = 0,
    reused = 0, missing = {}, extras = {}, failures = {}, creationFailures = {},
    pending = #recipe.windows, finished = false, phase = "preparing",
  }
  local job = { report = report, children = {} }
  local timer, approvedIDs, createdIDs = nil, {}, {}
  local finish, guard, later

  finish = function(reason)
    if report.finished then return end
    report.finished = true
    report.pending = 0
    report.reason = reason
    report.phase = report.cancelled and "cancelled" or "finished"
    if timer then timer:stop(); timer = nil end
    -- Invalidate callbacks before terminating a task or frame-placement job.
    for _, child in ipairs(job.children) do child:cancel() end
    complete(report)
  end
  function job:cancel()
    if report.finished then return end
    report.cancelled = true
    finish("establish-cancelled")
  end
  guard = function()
    if report.finished then return false end
    local ok, allowed, reason = pcall(options.guard)
    if not ok or not allowed then
      finish(ok and (reason or "context-unavailable") or "context-unavailable")
      return false
    end
    return true
  end
  later = function(callback)
    if report.finished then return end
    local ok, scheduled = pcall(options.scheduleAfter, 0.25, function()
      timer = nil
      if guard() then callback() end
    end)
    if not ok or not scheduled then finish("could-not-schedule-window-check")
    else timer = scheduled end
  end

  local function collect()
    if not guard() then return nil end
    local ok, candidates, err, seenIDs = pcall(options.collect)
    if not ok or not candidates then
      finish(ok and err or "could-not-enumerate-workspace-windows")
      return nil
    end
    if not guard() then return nil end
    return candidates, seenIDs or {}
  end
  local function matches(candidates)
    local eligible = {}
    for _, candidate in ipairs(candidates) do
      if approvedIDs[candidate.id] then table.insert(eligible, candidate) end
    end
    return assert(logic.matchWindows(recipe, eligible))
  end
  local function missingFor(candidates, bundleID)
    local missing = {}
    for _, slot in ipairs(matches(candidates).missing) do
      if slot.bundleID == bundleID then table.insert(missing, slot) end
    end
    return missing
  end
  local function rememberNew(candidates, baseline, bundleID)
    for _, candidate in ipairs(candidates) do
      if candidate.bundleID == bundleID and not baseline[candidate.id] then
        approvedIDs[candidate.id] = true
        if not createdIDs[candidate.id] then
          createdIDs[candidate.id] = true
          report.created = report.created + 1
        end
      end
    end
  end
  local function creationFailure(app, reason)
    table.insert(report.creationFailures, {
      bundleID = app.bundleID, appName = app.appName, reason = reason,
    })
  end
  local function keep(child)
    if child then table.insert(job.children, child) end
  end

  local initial = collect()
  if not initial then return job end
  for _, candidate in ipairs(initial) do approvedIDs[candidate.id] = true end
  local apps, seen = {}, {}
  for _, slot in ipairs(recipe.windows) do
    if not seen[slot.bundleID] then
      seen[slot.bundleID] = true
      table.insert(apps, { bundleID = slot.bundleID, appName = slot.appName })
    end
  end
  table.sort(apps, function(a, b) return a.bundleID < b.bundleID end)

  local function placeAll()
    local candidates = collect()
    if not candidates then return end
    local matched = matches(candidates)
    report.missing, report.extras = matched.missing, matched.extras
    for _, candidate in ipairs(candidates) do
      if not approvedIDs[candidate.id] then table.insert(report.extras, candidate) end
    end
    report.phase, report.pending = "placing", #matched.assignments
    local starting = true
    local function ready()
      if not starting and not report.finished and report.pending == 0 then finish() end
    end
    for _, assignment in ipairs(matched.assignments) do
      if not guard() then break end
      keep(options.place(assignment, function(success, reason, actual)
        if report.finished then return end
        if success then
          report.applied = report.applied + 1
          if not createdIDs[assignment.candidate.id] then report.reused = report.reused + 1 end
        else
          table.insert(report.failures, {
            target = assignment.target, reason = reason, actualFrame = actual,
          })
        end
        report.pending = report.pending - 1
        ready()
      end))
    end
    starting = false
    ready()
  end

  local appIndex = 0
  local nextApp
  nextApp = function()
    if not guard() then return end
    appIndex = appIndex + 1
    local app = apps[appIndex]
    if not app then placeAll(); return end
    local candidates = collect()
    if not candidates then return end
    local missing = missingFor(candidates, app.bundleID)
    if #missing == 0 then nextApp(); return end
    local supported, reason = options.support(app.bundleID)
    if not supported then creationFailure(app, reason); nextApp(); return end

    -- A failed/late creation is never retried. A retry might create a second
    -- window after the first Apple event finally completes.
    local remainingRequests = #missing
    local createOne
    createOne = function()
      local current, baseline = collect()
      if not current then return end
      if #missingFor(current, app.bundleID) == 0 then nextApp(); return end
      if remainingRequests == 0 then
        creationFailure(app, "windows-disappeared-during-establish")
        nextApp(); return
      end
      for _, candidate in ipairs(current) do baseline[candidate.id] = true end
      remainingRequests = remainingRequests - 1
      report.phase = "creating"
      keep(options.create(app.bundleID, function(success, createErr)
        if not guard() then return end
        if not success then creationFailure(app, createErr); nextApp(); return end
        local ticks = 0
        local function awaitWindow()
          local discovered = collect()
          if not discovered then return end
          local new = {}
          for _, candidate in ipairs(discovered) do
            if candidate.bundleID == app.bundleID and not baseline[candidate.id] then
              table.insert(new, candidate)
            end
          end
          if #new == 1 then
            rememberNew(new, baseline, app.bundleID)
            createOne()
          elseif #new > 1 then
            creationFailure(app, "ambiguous-new-windows")
            nextApp()
          else
            ticks = ticks + 1
            if ticks >= 24 then
              creationFailure(app, "new-window-not-in-destination-space")
              nextApp()
            else later(awaitWindow) end
          end
        end
        awaitWindow()
      end))
    end

    if options.isRunning(app.bundleID) then createOne(); return end
    report.phase = "launching"
    local _, baseline = collect()
    if not baseline then return end
    keep(options.launch(app.bundleID, function(success, launchErr)
      if not guard() then return end
      if not success then creationFailure(app, launchErr); nextApp(); return end
      local ticks, stableTicks, lastCount = 0, 0, -1
      local function awaitLaunch()
        local discovered = collect()
        if not discovered then return end
        local count = 0
        for _, candidate in ipairs(discovered) do
          if candidate.bundleID == app.bundleID and not baseline[candidate.id] then
            count = count + 1
          end
        end
        stableTicks = count == lastCount and stableTicks + 1 or 0
        lastCount, ticks = count, ticks + 1
        if options.isRunning(app.bundleID) and ((count > 0 and stableTicks >= 3) or ticks >= 20) then
          -- Count launch-created/default windows before requesting more.
          rememberNew(discovered, baseline, app.bundleID)
          createOne()
        elseif ticks >= 20 then
          creationFailure(app, "application-did-not-launch")
          nextApp()
        else later(awaitLaunch) end
      end
      awaitLaunch()
    end))
  end
  nextApp()
  return job
end

return establish
