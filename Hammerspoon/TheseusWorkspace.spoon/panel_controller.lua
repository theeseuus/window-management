-- UI workflow only. Capture and placement remain in the existing Spoon engine.
local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")
local panel = dofile(sourcePath .. "workspace_panel.lua")
local logic = dofile(sourcePath .. "panel_logic.lua")
local workspaceLogic = dofile(sourcePath .. "workspace_logic.lua")
local controller = {}

function controller.new(adapter)
  local ui = {}

  function ui:library(selectedName, errorText, clearQuery)
    self.snapshot, self.preview, self.pending = nil, nil, nil
    self.session:stopTimer()
    local catalog, err = adapter.catalog()
    if not catalog then
      if self.session then
        self.session:setState("library", { entries = {}, error = adapter.reason(err) })
      end
      return nil, err
    end
    self.session:setState("library", {
      entries = logic.entries(catalog), selectedName = selectedName,
      error = errorText, clearQuery = clearQuery,
    })
    return true
  end

  function ui:ready(errorText)
    self.pending = nil
    self.session:setState("ready", {
      capture = self.preview, error = errorText,
      message = string.format("%d %s captured", self.preview.windowCount,
        self.preview.windowCount == 1 and "window" or "windows"),
    })
  end

  function ui:capture()
    local session = self.session
    if session.state ~= "library" then return end
    local busy = adapter.busy()
    if busy then self:library(nil, adapter.reason(busy)); return end
    local context, err = adapter.context()
    if not context then self:library(nil, adapter.reason(err)); return end
    self.snapshot, self.preview, self.pending = nil, nil, nil
    session:setState("capturing", {
      message = "Capturing windows…", aspectRatio = context.screenFrame.w / context.screenFrame.h,
    })
    -- Paint the disabled capture form before the accessibility enumeration.
    session.timer = hs.timer.doAfter(0.05, function()
      session.timer = nil
      if self.session ~= session or session.closed or session.state ~= "capturing" then return end
      local ok, snapshot, captureErr = pcall(adapter.snapshot, context, session:windowID())
      if not ok then
        session:setState("failed", { message = "Capture could not be completed.", error = "Capture failed: " .. tostring(snapshot) })
        return
      end
      if not snapshot then
        session:setState("failed", { message = "Capture could not be completed.", error = adapter.reason(captureErr) })
        return
      end
      local recipe, recipeErr = workspaceLogic.buildRecipe("Unsaved layout", snapshot.records, snapshot.capturedAt)
      if not recipe then
        session:setState("failed", { message = "Capture could not be completed.", error = adapter.reason(recipeErr) })
        return
      end
      self.snapshot, self.preview = snapshot, logic.describe(recipe)
      self:ready()
    end)
  end

  function ui:save(name, replace)
    if not self.snapshot then return end
    local normalizedName, err = workspaceLogic.normalizeName(name)
    if not normalizedName then self:ready(adapter.reason(err)); return end
    local catalog, catalogErr = adapter.catalog()
    if not catalog then self:ready(adapter.reason(catalogErr)); return end
    local existing = catalog.recipes[normalizedName]
    if existing and not replace then
      self.pending = { name = normalizedName, recipe = logic.copy(existing) }
      self.session:setState("confirm-replace", {
        message = string.format("Replace “%s” with this captured layout? The existing recipe will be overwritten. No windows or apps are changed.", normalizedName),
      })
      return
    end
    self.session:setState("saving", { capture = self.preview, message = "Saving layout…" })
    local recipe, saveErr = adapter.save(normalizedName, self.snapshot, replace)
    if recipe then self:library(normalizedName, nil, true) else self:ready(adapter.reason(saveErr)) end
  end

  function ui:action(session, body)
    if self.session ~= session then return end
    local state, action = session.state, body.action
    if action == "close" and state == "library" then session:close(); return end
    if action == "cancel" and state ~= "saving" then
      if state == "confirm-replace" then self:ready()
      elseif state == "confirm-delete" then self:library(self.pending and self.pending.name)
      elseif state ~= "library" then self:library() end
      return
    end
    if state == "library" then
      if action == "capture" then self:capture(); return end
      if action ~= "restore" and action ~= "establish" and action ~= "delete" then return end
      if type(body.name) ~= "string" then return end
      local catalog, err = adapter.catalog()
      if not catalog then self:library(nil, adapter.reason(err)); return end
      local recipe = catalog.recipes[body.name]
      if not recipe then self:library(nil, adapter.reason("workspace-not-found")); return end
      if action == "delete" then
        self.pending = { name = body.name, recipe = logic.copy(recipe) }
        session:setState("confirm-delete", {
          message = string.format("Delete “%s”? Only the saved layout is removed. No windows, apps or Spaces are changed. This cannot be undone.", body.name),
        })
      else
        local busy = adapter.busy()
        if busy then self:library(body.name, adapter.reason(busy)); return end
        -- Retain the intended destination before closing changes keyboard focus.
        local context, contextErr = adapter.context()
        if not context then self:library(body.name, adapter.reason(contextErr)); return end
        local name = body.name
        session:close()
        adapter.apply(action, name, context)
      end
    elseif state == "ready" and action == "save" and type(body.name) == "string" then
      self:save(body.name, false)
    elseif (state == "confirm-delete" and action == "confirm-delete")
      or (state == "confirm-replace" and action == "confirm-replace") then
      local pending = self.pending
      if not pending then return end
      local catalog, err = adapter.catalog()
      if not catalog then
        if state == "confirm-replace" then self:ready(adapter.reason(err))
        else self:library(pending.name, adapter.reason(err)) end
        return
      end
      if not logic.sameRecipe(pending.recipe, catalog.recipes[pending.name]) then
        local message = "The saved layout changed while confirmation was open. Review it and try again."
        if state == "confirm-replace" then self:ready(message) else self:library(pending.name, message) end
        return
      end
      if state == "confirm-delete" then
        local deleted, deleteErr = adapter.delete(pending.name)
        self:library(nil, not deleted and adapter.reason(deleteErr) or nil)
      else self:save(pending.name, true) end
    end
  end

  function ui:show(startCapture)
    if self.session and not self.session.closed then
      local session = self.session
      if session.state == "library" then
        local context, err = adapter.context()
        if not context then adapter.alert(adapter.reason(err)); return end
        session.model.aspectRatio = context.screenFrame.w / context.screenFrame.h
        self:library()
        if startCapture then
          if session.loaded then self:capture() else self.startCapture = true end
        end
      end
      session:bringToFront()
      return
    end
    local context, contextErr = adapter.context()
    if not context then adapter.alert(adapter.reason(contextErr)); return end
    local catalog, catalogErr = adapter.catalog()
    if not catalog then adapter.alert(adapter.reason(catalogErr)); return end
    self.startCapture = startCapture == true
    local ok, opened = pcall(panel.open, context.screenFrame, {
      loaded = function(session)
        if self.session == session and self.startCapture then
          self.startCapture = false
          self:capture()
        end
      end,
      action = function(session, body) self:action(session, body) end,
      closed = function(session)
        if self.session == session then
          self.session, self.snapshot, self.preview, self.pending, self.startCapture = nil, nil, nil, nil, nil
        end
      end,
    }, { entries = logic.entries(catalog), aspectRatio = context.screenFrame.w / context.screenFrame.h })
    if ok then self.session = opened else adapter.alert("Could not open Workspaces: " .. tostring(opened)) end
  end

  function ui:close() if self.session then self.session:close() end end
  return ui
end

return controller
