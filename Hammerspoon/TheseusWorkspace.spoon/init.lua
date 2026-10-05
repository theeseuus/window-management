----------------------------------------------------------------------
-- TheseusWorkspace Spoon
-- Capture and reconcile cross-application window layouts in the current
-- ordinary user Space. This Spoon is independent of TheseusWindow.
----------------------------------------------------------------------

local obj = {}
obj.__index = obj

obj.name = "TheseusWorkspace"
obj.version = "0.1.3"
obj.author = "Theeseuus"
obj.license = "MIT"

-- User configuration
obj.settingsKey = "TheseusWorkspaceRecipesV1"
obj.animationDuration = 0
obj.excludedBundleIDs = {}

local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local workspaceLogic = dofile(sourcePath .. "workspace_logic.lua")
local frameRestore = dofile(sourcePath .. "frame_restore.lua")
local captureDialog = dofile(sourcePath .. "capture_dialog.lua")

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
    ["active-space-changed"] = "the active Space changed during capture; cancel and try again",
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

local function describeWindow(controller, window, context)
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
      frame = copyFrame(window:frame()),
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
      skipped["capture-dialog"] = (skipped["capture-dialog"] or 0) + 1
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

local function chooserChoices(controller)
  local workspaces, workspacesErr = controller:listWorkspaces()
  if not workspaces then
    return nil, workspacesErr
  end

  local choices = {}
  for _, workspace in ipairs(workspaces) do
    table.insert(choices, {
      text = workspace.name,
      subText = string.format(
        "%d windows · %s · captured %s",
        workspace.windowCount,
        workspace.applications,
        workspace.capturedAt
      ),
      workspaceName = workspace.name,
    })
  end
  return choices
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

  local context, contextErr = currentUserSpaceContext()
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
        animationDuration = tonumber(self.animationDuration),
        scheduleAfter = hs.timer.doAfter,
        guard = function()
          local activeOK, activeSpace = pcall(hs.spaces.activeSpaceOnScreen, context.screen)
          if not activeOK or activeSpace ~= context.spaceID then
            return false, "active-space-changed"
          end
          local record, reason = describeWindow(self, window, context)
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

function obj:promptCaptureCurrentWorkspace()
  if self._captureDialog then
    self._captureDialog:bringToFront()
    return self
  end
  -- Select the original window's screen/Space before the dialog takes focus.
  local context, contextErr = currentUserSpaceContext()
  if not context then
    showAlert("WORKSPACE: " .. reasonText(contextErr))
    return self
  end
  local snapshot
  local ok, sessionOrError = pcall(captureDialog.open, context.screenFrame, {
    capture = function(session)
      local snapshotErr
      snapshot, snapshotErr = takeSnapshot(self, context, session:windowID())
      if not snapshot then
        session:failed("Capture failed: " .. reasonText(snapshotErr))
        return
      end
      session:ready(string.format(
        "Snapshot ready · %d %s. You can move windows now; name and save this snapshot.",
        #snapshot.records, #snapshot.records == 1 and "window" or "windows"
      ))
    end,
    save = function(session, name)
      if not snapshot then return end
      local normalizedName, nameErr = workspaceLogic.normalizeName(name)
      if not normalizedName then session:ready(reasonText(nameErr)); return end
      local catalog, catalogErr = loadCatalog(self)
      if not catalog then session:ready(reasonText(catalogErr)); return end
      local replace = false
      if catalog.recipes[normalizedName] then
        local response = hs.dialog.blockAlert(
          "Replace workspace?",
          string.format("A workspace named “%s” already exists.", normalizedName),
          "Replace", "Cancel", "warning"
        )
        if session.closed then return end
        if response ~= "Replace" then
          session:ready("Replacement cancelled. Choose another name or cancel.")
          return
        end
        replace = true
      end
      local recipe, saveErr = saveSnapshot(self, normalizedName, snapshot, { replace = replace })
      if recipe then session:close() else session:ready(reasonText(saveErr)) end
    end,
    closed = function(session)
      snapshot = nil
      if self._captureDialog == session then self._captureDialog = nil end
    end,
  })
  if ok then
    self._captureDialog = sessionOrError
  else
    showAlert("WORKSPACE: could not open capture dialog: " .. tostring(sessionOrError), context.screen)
  end
  return self
end

local function closeRestoreChooser(controller)
  local session = controller._restoreChooserSession
  controller._restoreChooserSession = nil
  controller._restoreChooser = nil
  if not session then return end
  local deleteHotkey = session.deleteHotkey
  session.deleteHotkey = nil
  if deleteHotkey then deleteHotkey:delete() end
  if session.chooser then
    session.chooser:cancel()
    session.chooser:delete()
  end
end

function obj:showRestoreChooser()
  closeRestoreChooser(self)
  local choices, choicesErr = chooserChoices(self)
  if not choices then
    showAlert("WORKSPACE: " .. reasonText(choicesErr))
    return self
  end
  if #choices == 0 then
    showAlert("WORKSPACE: no captured workspaces")
    return self
  end

  local session = {}
  self._restoreChooserSession = session
  local chooser = hs.chooser.new(function(choice)
    if self._restoreChooserSession ~= session or session.confirming then return end
    closeRestoreChooser(self)
    if choice and choice.workspaceName then
      self:restoreWorkspace(choice.workspaceName)
    end
  end)
  session.chooser = chooser
  self._restoreChooser = chooser

  local function confirmDelete(choice)
    if self._restoreChooserSession ~= session or session.confirming
      or not chooser:isVisible() or not choice or not choice.workspaceName then
      return
    end
    -- Freeze the target before dismissing the chooser. Filtered row numbers
    -- are not indexes into the original, unfiltered choices table.
    local name = choice.workspaceName
    local query, selectedRow = chooser:query(), chooser:selectedRow()
    session.confirming = true
    chooser:hide()
    local response = hs.dialog.blockAlert(
      "Delete saved layout?",
      string.format(
        "Delete “%s”? Only the saved layout is removed. No windows, apps, or Spaces are changed. This cannot be undone.",
        name
      ),
      "Cancel", "Delete", "warning"
    )
    -- A stopped Spoon or replacement chooser must invalidate an old prompt.
    if self._restoreChooserSession ~= session then return end
    session.confirming = false
    if response == "Delete" then self:deleteWorkspace(name) end

    local refreshed, refreshErr = chooserChoices(self)
    if not refreshed or #refreshed == 0 then
      closeRestoreChooser(self)
      if refreshErr then showAlert("WORKSPACE: " .. reasonText(refreshErr)) end
      return
    end
    chooser:choices(refreshed):query(query):show()
    if response ~= "Delete" then chooser:selectedRow(selectedRow) end
  end

  session.deleteHotkey = hs.hotkey.new({ "cmd" }, "delete", function()
    if self._restoreChooserSession ~= session or not chooser:isVisible() then return end
    confirmDelete(chooser:selectedRowContents())
  end)
  chooser
    :placeholderText("Restore in this Space · ⌘Delete or right-click to delete")
    :searchSubText(true)
    :showCallback(function()
      if self._restoreChooserSession == session and session.deleteHotkey then
        session.deleteHotkey:enable()
      end
    end)
    :hideCallback(function()
      if session.deleteHotkey then session.deleteHotkey:disable() end
    end)
    :rightClickCallback(function(row)
      if row == 0 or self._restoreChooserSession ~= session then return end
      local choice = chooser:selectedRowContents(row)
      if not choice.workspaceName then return end
      local menu = hs.menubar.new(false)
      if not menu then return end
      local requested = false
      menu:setMenu({ {
        title = "Delete saved layout…",
        fn = function() requested = true end,
      } })
      menu:popupMenu(hs.mouse.absolutePosition())
      menu:delete()
      -- Open the confirmation only after the context menu has closed.
      if requested then confirmDelete(choice) end
    end)
    :choices(choices)
    :show()
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
    capture = function() self:promptCaptureCurrentWorkspace() end,
    restore = function() self:showRestoreChooser() end,
  }
  for _, actionName in ipairs({ "capture", "restore" }) do
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
  if self._captureDialog then self._captureDialog:close() end
  if self._restoreOperation then
    local operation = self._restoreOperation
    operation.report.cancelled = true
    for _, job in ipairs(operation.jobs) do job:cancel() end
  end
  closeRestoreChooser(self)
  self:_unbindHotkeys()
  return self
end

return obj
