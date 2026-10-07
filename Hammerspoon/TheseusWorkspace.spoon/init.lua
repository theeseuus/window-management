----------------------------------------------------------------------
-- TheseusWorkspace Spoon
-- Capture, restore, and establish cross-application window layouts in the current
-- ordinary user Space. This Spoon is independent of TheseusWindow.
----------------------------------------------------------------------

local obj = {}
obj.__index = obj

obj.name = "TheseusWorkspace"
obj.version = "0.4.1"
obj.author = "Theeseuus"
obj.license = "MIT"

-- User configuration
obj.settingsKey = "TheseusWorkspaceRecipesV1"
obj.animationDuration = 0
obj.excludedBundleIDs = {}

local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local workspaceLogic = dofile(sourcePath .. "workspace_logic.lua")
local frameRestore = dofile(sourcePath .. "frame_restore.lua")
local panelController = dofile(sourcePath .. "panel_controller.lua")
local windowFactory = dofile(sourcePath .. "window_factory.lua")
local workspaceEstablish = dofile(sourcePath .. "workspace_establish.lua")

local function copyFrame(frame)
  return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function showAlert(text, screen, duration)
  screen = screen or hs.screen.mainScreen()
  if not screen then return end
  hs.alert.show(
    text,
    { strokeWidth = 0, fillColor = { alpha = 0.88 } },
    screen,
    duration or 1.8
  )
end

local function reasonText(reason)
  local reasons = {
    ["empty-name"] = "enter a workspace name",
    ["invalid-name"] = "workspace name must be text",
    ["invalid-name-characters"] = "workspace name cannot contain control characters",
    ["name-too-long"] = "workspace name must be 80 characters or fewer",
    ["workspace-exists"] = "a workspace with that name already exists",
    ["workspace-not-found"] = "workspace was not found",
    ["no-windows"] = "no eligible windows are present in this Space",
    ["active-space-changed"] = "the active Space changed; try again in the intended Space",
    ["establish-in-progress"] = "Establish is already in progress; wait for completion",
    ["restore-in-progress"] = "Restore is already in progress; wait for completion",
    ["unsupported-application"] = "missing-window creation is not supported for this app",
    ["excluded-application"] = "this app is excluded from workspace management",
    ["application-not-installed"] = "the app is not installed",
    ["ghostty-requires-applescript-1.3"] = "Ghostty 1.3 or later with AppleScript support is required",
    ["automation-not-authorized"] = "macOS automation access has not been granted",
    ["window-command-timed-out"] = "the window command timed out; check any automation permission prompt before retrying",
    ["new-window-not-in-destination-space"] = "no new eligible window appeared in this Space",
    ["ambiguous-new-windows"] = "more than one new window appeared; left them untouched",
    ["application-did-not-launch"] = "the app did not become ready before the launch timeout",
    ["new-window-command-unavailable"] = "this app's genuine New Window command is unavailable",
    ["new-window-menu-disabled"] = "this app's New Window menu is disabled; no fallback was used",
    ["new-window-not-focused"] = "the new window could not become active; stopped creating more windows",
    ["application-not-running"] = "the app is no longer running",
    ["application-identity-mismatch"] = "the running app does not match the saved bundle identifier",
    ["claude-new-window-unavailable"] = "Claude has no verified independent-window command; reuse a local window or launch it from closed",
    ["window-command-failed"] = "the native app window command failed",
    ["windows-disappeared-during-establish"] = "windows closed during Establish; no extra replacements were requested",
  }
  return reasons[reason] or tostring(reason)
end

local function currentUserSpaceContext()
  local focusedWindow = hs.window.focusedWindow()
  local screen = focusedWindow and focusedWindow:screen() or hs.screen.mainScreen()
  if not screen then
    return nil, "no-screen"
  end

  local activeOK, spaceID, activeErr = pcall(hs.spaces.activeSpaceOnScreen, screen)
  if not activeOK then
    return nil, "could not read the active Space: " .. tostring(spaceID)
  end
  if not spaceID then
    return nil, "could not read the active Space: " .. tostring(activeErr)
  end

  local typeOK, spaceType, typeErr = pcall(hs.spaces.spaceType, spaceID)
  if not typeOK then
    return nil, "could not read the active Space type: " .. tostring(spaceType)
  end
  if spaceType ~= "user" then
    return nil, "the active Space is not an ordinary user Space: " .. tostring(typeErr or spaceType)
  end

  return {
    screen = screen,
    screenFrame = copyFrame(screen:frame()),
    spaceID = spaceID,
  }
end

local function operationContext(options)
  if not options._context then return currentUserSpaceContext() end
  local context = options._context
  local ok, activeSpace = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
  if not ok or activeSpace ~= context.spaceID then return nil, "active-space-changed" end
  local typeOK, spaceType = pcall(hs.spaces.spaceType, context.spaceID)
  if not typeOK or spaceType ~= "user" then return nil, "active-space-changed" end
  return context
end

local function describeWindow(controller, window, context, eligibilityOnly)
  local windowOK, recordOrReason = pcall(function()
    if not window:isStandard() then return "non-standard" end
    if not window:isVisible() then return "not-visible" end
    if window:isMinimized() then return "minimized" end
    if window:isFullScreen() then return "full-screen" end

    local screen = window:screen()
    if not screen or screen:id() ~= context.screen:id() then
      return "other-screen"
    end

    local spaces, spacesErr = hs.spaces.windowSpaces(window)
    if not spaces then
      return "space-membership-unavailable:" .. tostring(spacesErr)
    end
    if #spaces ~= 1 or spaces[1] ~= context.spaceID then
      return "not-exclusive-to-current-space"
    end

    local app = window:application()
    if not app then return "missing-application" end
    local bundleID = app:bundleID()
    if type(bundleID) ~= "string" or bundleID == "" then
      return "missing-bundle-id"
    end
    if controller.excludedBundleIDs[bundleID] then
      return "excluded-application"
    end

    return {
      id = window:id(),
      bundleID = bundleID,
      appName = app:title() or bundleID,
      frame = not eligibilityOnly and copyFrame(window:frame()) or nil,
      screenFrame = context.screenFrame,
      window = window,
    }
  end)

  if not windowOK then
    return nil, "window-inspection-failed:" .. tostring(recordOrReason)
  end
  if type(recordOrReason) == "string" then
    return nil, recordOrReason
  end
  return recordOrReason
end

local function collectCurrentWindows(controller, context, excludedWindowID)
  local panel = controller._workspaceUI and controller._workspaceUI.session
  excludedWindowID = excludedWindowID or (panel and panel:windowID())
  local windowsOK, windowIDs, windowsErr = pcall(hs.spaces.windowsForSpace, context.spaceID)
  if not windowsOK then
    return nil, "could not enumerate windows in the active Space: " .. tostring(windowIDs)
  end
  if not windowIDs then
    return nil, "could not enumerate windows in the active Space: " .. tostring(windowsErr)
  end

  -- hs.window.get() enumerates every application's windows on each call.
  -- Build one ID index instead of repeating that work for every Space ID.
  local allOK, allWindows = pcall(hs.window.allWindows)
  if not allOK or type(allWindows) ~= "table" then
    return nil, "could not enumerate application windows: " .. tostring(allWindows)
  end
  local windowsByID = {}
  for _, window in ipairs(allWindows) do
    local idOK, id = pcall(function() return window:id() end)
    if idOK and id then windowsByID[id] = window end
  end

  local records = {}
  local skipped = {}
  for _, windowID in ipairs(windowIDs) do
    local window = windowsByID[windowID]
    if windowID == excludedWindowID then
      skipped["workspace-panel"] = (skipped["workspace-panel"] or 0) + 1
    elseif window then
      local record, reason = describeWindow(controller, window, context)
      if record then
        table.insert(records, record)
      else
        skipped[reason] = (skipped[reason] or 0) + 1
      end
    else
      skipped["window-unavailable"] = (skipped["window-unavailable"] or 0) + 1
    end
  end

  return records, {
    enumerated = #windowIDs,
    eligible = #records,
    skipped = skipped,
  }
end

local function loadCatalog(controller)
  local getOK, catalog = pcall(hs.settings.get, controller.settingsKey)
  if not getOK then
    return nil, "could not load workspace settings: " .. tostring(catalog)
  end
  if catalog == nil then
    return workspaceLogic.newCatalog()
  end

  local valid, catalogErr = workspaceLogic.validateCatalog(catalog)
  if not valid then
    return nil, "workspace settings are invalid: " .. tostring(catalogErr)
  end
  return catalog
end

-- Establish enumerates only the apps named in the recipe, not the whole
-- desktop. Retain all observed IDs so an old hidden/minimized window cannot
-- be mistaken for a newly created one when it becomes visible.
local function collectRecipeWindows(controller, recipe, context, onlyBundleID)
  local records, seenIDs, bundles = {}, {}, {}
  for _, slot in ipairs(recipe.windows) do
    if not onlyBundleID or slot.bundleID == onlyBundleID then bundles[slot.bundleID] = true end
  end
  local ordered = {}
  for bundleID in pairs(bundles) do table.insert(ordered, bundleID) end
  table.sort(ordered)
  for _, bundleID in ipairs(ordered) do
    if not controller.excludedBundleIDs[bundleID] then
      local ok, windows = pcall(function()
        local app = hs.application.get(bundleID)
        return app and app:allWindows() or {}
      end)
      if not ok or type(windows) ~= "table" then
        return nil, "could-not-enumerate-workspace-windows"
      end
      for _, window in ipairs(windows) do
        local idOK, id = pcall(function() return window:id() end)
        if not idOK or not id then return nil, "could-not-read-window-id" end
        if not seenIDs[id] then
          seenIDs[id] = true
          local record = describeWindow(controller, window, context)
          if record and record.bundleID == bundleID then
            local frame, err = workspaceLogic.normalizeFrame(record.frame, context.screenFrame)
            if not frame then return nil, err end
            record.frame = frame
            table.insert(records, record)
          end
        end
      end
    end
  end
  return records, nil, seenIDs
end

local function saveCatalog(controller, catalog)
  local valid, catalogErr = workspaceLogic.validateCatalog(catalog)
  if not valid then
    return nil, "refusing to save invalid workspace settings: " .. tostring(catalogErr)
  end

  local setOK, setErr = pcall(hs.settings.set, controller.settingsKey, catalog)
  if not setOK then
    return nil, "could not save workspace settings: " .. tostring(setErr)
  end

  local readOK, savedCatalog = pcall(hs.settings.get, controller.settingsKey)
  if not readOK then
    return nil, "could not verify saved workspace settings: " .. tostring(savedCatalog)
  end
  local savedValid, savedErr = workspaceLogic.validateCatalog(savedCatalog)
  if not savedValid then
    return nil, "saved workspace settings failed validation: " .. tostring(savedErr)
  end
  return true
end


local function takeSnapshot(controller, context, excludedWindowID)
  local capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local activeOK, activeSpace = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
  if not activeOK or activeSpace ~= context.spaceID then
    return nil, "active-space-changed"
  end
  local records, collection = collectCurrentWindows(controller, context, excludedWindowID)
  if not records then return nil, collection end
  if #records == 0 then return nil, "no-windows" end
  activeOK, activeSpace = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
  if not activeOK or activeSpace ~= context.spaceID then
    return nil, "active-space-changed"
  end
  -- Retain plain geometry/identity values, never live window handles, while naming.
  for _, record in ipairs(records) do record.window = nil end
  return { records = records, collection = collection, capturedAt = capturedAt, context = context }
end

local function saveSnapshot(controller, name, snapshot, options)
  options = options or {}
  local normalizedName, nameErr = workspaceLogic.normalizeName(name)
  if not normalizedName then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(nameErr)) end
    return nil, nameErr
  end

  -- Re-read the catalog at save time, preserving recipes changed while naming.
  local catalog, catalogErr = loadCatalog(controller)
  if not catalog then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(catalogErr)) end
    return nil, catalogErr
  end
  if catalog.recipes[normalizedName] and not options.replace then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText("workspace-exists")) end
    return nil, "workspace-exists"
  end

  local context, collection = snapshot.context, snapshot.collection
  local recipe, recipeErr = workspaceLogic.buildRecipe(
    normalizedName,
    snapshot.records,
    snapshot.capturedAt
  )
  if not recipe then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(recipeErr), context.screen) end
    return nil, recipeErr
  end

  catalog.recipes[normalizedName] = recipe
  local saved, saveErr = saveCatalog(controller, catalog)
  if not saved then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(saveErr), context.screen) end
    return nil, saveErr
  end

  local report = {
    name = normalizedName,
    captured = #recipe.windows,
    enumerated = collection.enumerated,
    skippedCount = collection.enumerated - collection.eligible,
    skipped = collection.skipped,
    replaced = options.replace == true,
  }
  if not options.silent then
    showAlert(
      string.format(
        "CAPTURED %s · %d windows · %d skipped",
        normalizedName,
        report.captured,
        report.skippedCount
      ),
      context.screen
    )
  end
  return recipe, report
end

function obj:captureCurrentWorkspace(name, options)
  options = options or {}
  local normalizedName, nameErr = workspaceLogic.normalizeName(name)
  if not normalizedName then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(nameErr)) end
    return nil, nameErr
  end
  local catalog, catalogErr = loadCatalog(self)
  if not catalog then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(catalogErr)) end
    return nil, catalogErr
  end
  if catalog.recipes[normalizedName] and not options.replace then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText("workspace-exists")) end
    return nil, "workspace-exists"
  end
  local context, contextErr = currentUserSpaceContext()
  if not context then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(contextErr)) end
    return nil, contextErr
  end
  local snapshot, snapshotErr = takeSnapshot(self, context)
  if not snapshot then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(snapshotErr), context.screen) end
    return nil, snapshotErr
  end
  return saveSnapshot(self, normalizedName, snapshot, options)
end

function obj:restoreWorkspace(name, options)
  options = options or {}
  if self._establishOperation then
    if not options.silent then showAlert("WORKSPACE: Establish is already in progress") end
    return nil, "establish-in-progress"
  end
  if self._restoreOperation then
    if not options.silent then showAlert("WORKSPACE: a restore is already in progress") end
    return nil, "restore-in-progress"
  end
  local normalizedName, nameErr = workspaceLogic.normalizeName(name)
  if not normalizedName then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(nameErr)) end
    return nil, nameErr
  end

  local catalog, catalogErr = loadCatalog(self)
  if not catalog then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(catalogErr)) end
    return nil, catalogErr
  end
  local recipe = catalog.recipes[normalizedName]
  if not recipe then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText("workspace-not-found")) end
    return nil, "workspace-not-found"
  end

  local context, contextErr = operationContext(options)
  if not context then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(contextErr)) end
    return nil, contextErr
  end

  local records, collectionErr = collectCurrentWindows(self, context)
  if not records then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(collectionErr), context.screen) end
    return nil, collectionErr
  end

  local candidates = {}
  for _, record in ipairs(records) do
    local normalizedFrame, frameErr = workspaceLogic.normalizeFrame(
      record.frame,
      record.screenFrame
    )
    if not normalizedFrame then
      if not options.silent then showAlert("WORKSPACE: " .. reasonText(frameErr), context.screen) end
      return nil, frameErr
    end
    table.insert(candidates, {
      id = record.id,
      bundleID = record.bundleID,
      appName = record.appName,
      frame = normalizedFrame,
      window = record.window,
    })
  end

  local matches, matchErr = workspaceLogic.matchWindows(recipe, candidates)
  if not matches then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(matchErr), context.screen) end
    return nil, matchErr
  end

  local report = {
    name = normalizedName,
    requested = #recipe.windows,
    applied = 0,
    missing = matches.missing,
    extras = matches.extras,
    failures = {},
    pending = #matches.assignments,
    finished = false,
  }

  local operation = { jobs = {}, report = report, launching = true }
  self._restoreOperation = operation

  local function finishIfReady()
    if operation.launching or report.pending ~= 0 or report.finished then return end
    report.finished = true
    self._restoreOperation = nil
    self.lastRestoreReport = report
    if not options.silent and not report.cancelled then
      local message = string.format(
        "RESTORED %s · %d placed · %d missing · %d extra · %d failed",
        normalizedName, report.applied, #report.missing, #report.extras, #report.failures
      )
      for _, category in ipairs({
        { label = "Missing", slots = report.missing },
        { label = "Failed", slots = report.failures },
      }) do
        local names, seen = {}, {}
        for _, entry in ipairs(category.slots) do
          local name = (entry.target or entry).appName
          if not seen[name] then
            table.insert(names, name)
            seen[name] = true
          end
        end
        table.sort(names)
        if #names > 0 then
          message = message .. "\n" .. category.label .. ": " .. table.concat(names, ", ")
        end
      end
      showAlert(message, context.screen, #report.failures > 0 and 5 or 4)
    end
    if type(options.onComplete) == "function" then
      local ok, err = pcall(options.onComplete, report)
      if not ok then report.callbackError = tostring(err) end
    end
  end

  for _, assignment in ipairs(matches.assignments) do
    local targetFrame, frameErr = workspaceLogic.absoluteFrame(
      assignment.target.frame,
      context.screenFrame
    )
    if not targetFrame then
      table.insert(report.failures, {
        target = assignment.target,
        reason = frameErr,
      })
      report.pending = report.pending - 1
    else
      local window = assignment.candidate.window
      local job = frameRestore.place(window, targetFrame, {
        initialFrame = workspaceLogic.absoluteFrame(assignment.candidate.frame, context.screenFrame),
        animationDuration = tonumber(self.animationDuration),
        scheduleAfter = hs.timer.doAfter,
        guard = function()
          local activeOK, activeSpace = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
          if not activeOK or activeSpace ~= context.spaceID then
            return false, "active-space-changed"
          end
          local record, reason = describeWindow(self, window, context, true)
          if not record or record.id ~= assignment.candidate.id then
            return false, reason or "window-no-longer-available"
          end
          return true
        end,
      }, function(success, reason, actual)
        if success then
          report.applied = report.applied + 1
        else
          table.insert(report.failures, {
            target = assignment.target,
            reason = reason,
            actualFrame = actual,
          })
        end
        report.pending = report.pending - 1
        finishIfReady()
      end)
      table.insert(operation.jobs, job)
    end
  end

  operation.launching = false
  finishIfReady()
  return report
end

function obj:establishWorkspace(name, options)
  options = options or {}
  local busy = self._establishOperation and "establish-in-progress"
    or (self._restoreOperation and "restore-in-progress")
  if busy then
    if not options.silent then showAlert("WORKSPACE: an operation is already in progress") end
    return nil, busy
  end
  local normalizedName, err = workspaceLogic.normalizeName(name)
  local catalog
  if normalizedName then catalog, err = loadCatalog(self) end
  local recipe = catalog and catalog.recipes[normalizedName]
  if catalog and not recipe then err = "workspace-not-found" end
  if not recipe then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(err)) end
    return nil, err
  end
  local context, contextErr = operationContext(options)
  if not context then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(contextErr)) end
    return nil, contextErr
  end

  local session = {}
  self._establishOperation = session
  local function guard()
    if session.cancelled then return false, "establish-cancelled" end
    local ok, active = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
    return ok and active == context.spaceID, "active-space-changed"
  end
  if not options.silent then showAlert("ESTABLISHING " .. normalizedName, context.screen) end
  session.job = workspaceEstablish.start(recipe, {
    guard = guard,
    scheduleAfter = hs.timer.doAfter,
    collect = function(bundleID) return collectRecipeWindows(self, recipe, context, bundleID) end,
    isRunning = function(bundleID) return hs.application.get(bundleID) ~= nil end,
    support = function(bundleID)
      if self.excludedBundleIDs[bundleID] then return false, "excluded-application" end
      return windowFactory.support(bundleID)
    end,
    launch = function(bundleID, complete)
      return windowFactory.launch(bundleID, { guard = guard }, complete)
    end,
    create = function(bundleID, complete)
      return windowFactory.create(bundleID, { guard = guard }, complete)
    end,
    createdWindowReady = function(candidate, complete)
      return windowFactory.createdWindowReady(candidate, {
        guard = function()
          local allowed, reason = guard()
          if not allowed then return false, reason end
          local record, err = describeWindow(self, candidate.window, context, true)
          return record ~= nil and record.id == candidate.id, err or "window-no-longer-available"
        end,
      }, complete)
    end,
    place = function(assignment, complete)
      local target = assert(workspaceLogic.absoluteFrame(assignment.target.frame, context.screenFrame))
      local window = assignment.candidate.window
      return frameRestore.place(window, target, {
        initialFrame = workspaceLogic.absoluteFrame(assignment.candidate.frame, context.screenFrame),
        animationDuration = tonumber(self.animationDuration),
        scheduleAfter = hs.timer.doAfter,
        guard = function()
          local allowed, reason = guard()
          if not allowed then return false, reason end
          local record, recordErr = describeWindow(self, window, context, true)
          if not record or record.id ~= assignment.candidate.id then
            return false, recordErr or "window-no-longer-available"
          end
          return true
        end,
      }, complete)
    end,
  }, function(report)
    if self._establishOperation == session then self._establishOperation = nil end
    self.lastEstablishReport = report
    if not options.silent and not report.cancelled then
      local message = string.format(
        "ESTABLISHED %s · %d placed · %d new · %d missing · %d failed",
        normalizedName, report.applied, report.created, #report.missing, #report.failures
      )
      if report.reason then message = "ESTABLISH stopped · " .. reasonText(report.reason) end
      for _, failure in ipairs(report.creationFailures) do
        message = message .. "\n" .. failure.appName .. ": " .. reasonText(failure.reason)
      end
      local failedNames, seen = {}, {}
      for _, failure in ipairs(report.failures) do
        local appName = failure.target.appName
        if not seen[appName] then table.insert(failedNames, appName); seen[appName] = true end
      end
      table.sort(failedNames)
      if #failedNames > 0 then message = message .. "\nFailed placement: " .. table.concat(failedNames, ", ") end
      showAlert(message, context.screen, 5)
    end
    if type(options.onComplete) == "function" then
      local ok, callbackErr = pcall(options.onComplete, report)
      if not ok then report.callbackError = tostring(callbackErr) end
    end
  end)
  return session.job.report
end

function obj:listWorkspaces()
  local catalog, catalogErr = loadCatalog(self)
  if not catalog then return nil, catalogErr end

  local workspaces = {}
  for name, recipe in pairs(catalog.recipes) do
    local applications, summaryErr = workspaceLogic.applicationSummary(recipe)
    if not applications then return nil, summaryErr end
    table.insert(workspaces, {
      name = name,
      capturedAt = recipe.capturedAt,
      windowCount = #recipe.windows,
      applications = applications,
    })
  end
  table.sort(workspaces, function(left, right)
    return left.name:lower() < right.name:lower()
  end)
  return workspaces
end

function obj:deleteWorkspace(name, options)
  options = options or {}
  local normalizedName, nameErr = workspaceLogic.normalizeName(name)
  if not normalizedName then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(nameErr)) end
    return nil, nameErr
  end

  local catalog, catalogErr = loadCatalog(self)
  if not catalog then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(catalogErr)) end
    return nil, catalogErr
  end
  if not catalog.recipes[normalizedName] then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText("workspace-not-found")) end
    return nil, "workspace-not-found"
  end

  catalog.recipes[normalizedName] = nil
  local saved, saveErr = saveCatalog(self, catalog)
  if not saved then
    if not options.silent then showAlert("WORKSPACE: " .. reasonText(saveErr)) end
    return nil, saveErr
  end

  if not options.silent then
    showAlert("DELETED " .. normalizedName)
  end
  return true
end

local function workspaceUI(controller)
  if controller._workspaceUI then return controller._workspaceUI end
  controller._workspaceUI = panelController.new({
    context = currentUserSpaceContext,
    catalog = function() return loadCatalog(controller) end,
    snapshot = function(context, excludedID) return takeSnapshot(controller, context, excludedID) end,
    save = function(name, snapshot, replace)
      return saveSnapshot(controller, name, snapshot, { replace = replace, silent = true })
    end,
    delete = function(name) return controller:deleteWorkspace(name, { silent = true }) end,
    apply = function(action, name, context)
      if action == "restore" then controller:restoreWorkspace(name, { _context = context })
      else controller:establishWorkspace(name, { _context = context }) end
    end,
    busy = function()
      return controller._establishOperation and "establish-in-progress"
        or (controller._restoreOperation and "restore-in-progress")
    end,
    reason = reasonText,
    alert = function(message) showAlert("WORKSPACE: " .. message) end,
  })
  return controller._workspaceUI
end

function obj:showWorkspaces()
  workspaceUI(self):show()
  return self
end

-- Keep existing integrations compatible; neither API opens a second window.
function obj:showRestoreChooser() return self:showWorkspaces() end
function obj:promptCaptureCurrentWorkspace()
  workspaceUI(self):show(true)
  return self
end

function obj:_unbindHotkeys()
  if not self._hotkeys then return end
  for _, hotkey in pairs(self._hotkeys) do
    hotkey:delete()
  end
  self._hotkeys = nil
end

function obj:bindHotkeys(mapping)
  mapping = mapping or {}
  self:_unbindHotkeys()
  self._hotkeys = {}

  local actions = {
    workspaces = function() self:showWorkspaces() end,
    capture = function() self:promptCaptureCurrentWorkspace() end,
    restore = function() self:showWorkspaces() end,
  }
  for _, actionName in ipairs({ "workspaces", "capture", "restore" }) do
    local keySpec = mapping[actionName]
    if keySpec then
      self._hotkeys[actionName] = hs.hotkey.bindSpec(keySpec, actions[actionName])
    end
  end
  return self
end

function obj:start()
  return self
end

function obj:stop()
  if self._workspaceUI then self._workspaceUI:close(); self._workspaceUI = nil end
  if self._establishOperation then
    local session = self._establishOperation
    session.cancelled = true
    if session.job then session.job:cancel() end
  end
  if self._restoreOperation then
    local operation = self._restoreOperation
    operation.report.cancelled = true
    for _, job in ipairs(operation.jobs) do job:cancel() end
  end
  self:_unbindHotkeys()
  return self
end

return obj
