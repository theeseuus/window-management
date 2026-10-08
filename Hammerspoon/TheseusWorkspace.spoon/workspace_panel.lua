-- One local WKWebView for library, frozen capture, and inline confirmations.
local panel = {}
local sourcePath = debug.getinfo(1, "S").source:match("^@(.*/)")

local function readAsset(name)
  local file = assert(io.open(sourcePath .. name, "r"))
  local value = file:read("*a")
  file:close()
  return value
end

local html = readAsset("workspace_panel.html"):gsub("__PANEL_SCRIPT__", function()
  return readAsset("workspace_panel.js")
end)

local function systemIcons()
  local icons = {}
  if not hs.image then return icons end
  for key, name in pairs({ search = "NSTouchBarSearchTemplate", delete = "NSTouchBarDeleteTemplate" }) do
    local ok, url = pcall(function()
      local icon = hs.image.imageFromName(name)
      return icon and icon:encodeAsURLString(true)
    end)
    if ok and url then icons[key] = url end
  end
  return icons
end

function panel.open(screenFrame, callbacks, initial)
  local session = { state = "library", revision = 0, closed = false, loaded = false }
  local content = hs.webview.usercontent.new("TheseusWorkspacePanel")
  session.content = content
  initial.icons = systemIcons()
  session.model = initial

  function session:render()
    if self.closed or not self.loaded then return end
    local model = {}
    for key, value in pairs(self.model) do model[key] = value end
    model.state, model.revision = self.state, self.revision
    -- JSON is passed as an expression, never interpolated into HTML or a string.
    local json = hs.json.encode(model):gsub("\226\128\168", "\\u2028"):gsub("\226\128\169", "\\u2029")
    self.view:evaluateJavaScript("window.setWorkspaceState(" .. json .. ");", function(_, err)
      if self.closed then return end
      -- Hammerspoon 1.1.1 can report successful evaluations as { code = 0 }.
      local success = err == nil or (type(err) == "table" and err.code == 0
        and err.domain == nil and err.description == nil and err.localizedDescription == nil)
      if success then self.renderError = nil
      elseif type(err) == "table" then
        self.renderError = err.description or err.localizedDescription
          or ("JavaScript render error: " .. tostring(err.code or "unknown"))
      else self.renderError = tostring(err) end
    end)
  end

  function session:setState(state, values)
    if self.closed then return end
    self.state = state
    self.revision = self.revision + 1
    local model = { icons = self.model.icons, aspectRatio = self.model.aspectRatio }
    for key, value in pairs(values or {}) do model[key] = value end
    self.model = model
    self:render()
  end

  function session:stopTimer()
    if self.timer then self.timer:stop(); self.timer = nil end
  end

  local function finish(deleteView)
    if session.closed then return end
    session.closed, session.state = true, "closed"
    session:stopTimer()
    content:setCallback(nil)
    local view = session.view
    session.view = nil
    if deleteView and view then view:windowCallback(nil):delete() end
    if callbacks.closed then callbacks.closed(session) end
  end

  function session:close() finish(true) end
  function session:bringToFront()
    if not self.closed then self.view:show():bringToFront() end
  end
  function session:windowID()
    local window = self.view and self.view:hswindow()
    return window and window:id()
  end

  content:setCallback(function(message)
    local body = type(message) == "table" and message.body
    if session.closed or type(body) ~= "table" or type(body.action) ~= "string" then return end
    if body.action == "ready" then
      if session.loaded then return end
      session.loaded = true
      session:render()
      if callbacks.loaded then callbacks.loaded(session) end
      return
    end
    -- Discard queued events from a previous view, confirmation, or closed panel.
    if not session.loaded or body.revision ~= session.revision then return end
    local ok, err = pcall(callbacks.action, session, body)
    if not ok and not session.closed then
      session.model.error = "Action failed: " .. tostring(err)
      session:setState(session.state, session.model)
    end
  end)

  local width = math.min(660, screenFrame.w - 32)
  local height = math.min(520, screenFrame.h - 32)
  session.view = hs.webview.new({
    x = screenFrame.x + (screenFrame.w - width) / 2,
    y = screenFrame.y + (screenFrame.h - height) / 2,
    w = width, h = height,
  }, {
    privateBrowsing = true, javaScriptCanOpenWindowsAutomatically = false,
    developerExtrasEnabled = false,
  }, content)
  session.view
    :windowStyle({ "titled", "closable", "fullSizeContentView", "nonactivating" })
    :windowTitle("Window Factory")
    :allowTextEntry(true)
    :allowNewWindows(false)
    :closeOnEscape(false)
    :deleteOnClose(true)
    :transparent(true)
    :behavior(hs.drawing.windowBehaviors.moveToActiveSpace)
    :policyCallback(function(action, _, details)
      if action ~= "navigationAction" then return action == "navigationResponse" end
      local url = details and details.request and details.request.URL
      if type(url) == "table" then return url.url == "about:blank" end
      return url == nil or url == "about:blank"
    end)
    :windowCallback(function(action)
      if action == "closing" then finish(false) end
    end)
    :html(html)
    :show()
    :bringToFront()
  return session
end

return panel
