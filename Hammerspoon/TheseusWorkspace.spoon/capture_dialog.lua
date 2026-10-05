-- Local, non-blocking capture UI. No remote resources or persistent web data.
local dialog = {}

local html = [=[<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; form-action 'none'; base-uri 'none'">
<meta name="color-scheme" content="light dark"><title>Capture workspace</title>
<style>
  :root { color-scheme: light dark; font: 14px -apple-system, sans-serif; }
  body { margin: 0; padding: 24px; background: Canvas; color: CanvasText; }
  h1 { font-size: 20px; margin: 0 0 12px; }
  #status { min-height: 42px; line-height: 1.5; margin: 0 0 16px; }
  label { display: block; margin-bottom: 7px; }
  input { box-sizing: border-box; width: 100%; font: inherit; padding: 8px; border-radius: 6px; border: 1px solid GrayText; }
  input:disabled { opacity: .5; }
  .privacy { font-size: 12px; color: CanvasText; opacity: .7; line-height: 1.5; margin: 12px 0 18px; }
  .buttons { display: flex; justify-content: flex-end; gap: 10px; }
  button { font: inherit; padding: 7px 18px; border-radius: 6px; }
  #save:not(:disabled) { background: #1769ce; color: white; border: 1px solid #1769ce; }
</style></head><body>
<h1>Capture workspace</h1>
<p id="status" role="status" aria-live="polite">Capturing… Keep windows still until the snapshot is ready.</p>
<form id="capture-form">
  <label for="name">Workspace name</label>
  <input id="name" type="text" maxlength="80" autocomplete="off" disabled>
  <p class="privacy">Only application identities and window geometry are saved.<br>Window titles, document paths and contents are not stored.</p>
  <div class="buttons"><button id="cancel" type="button">Cancel</button><button id="save" type="submit" disabled>Save</button></div>
</form>
<script>
  let state = 'capturing';
  const nameField = document.getElementById('name');
  const saveButton = document.getElementById('save');
  const post = body => window.webkit.messageHandlers.TheseusWorkspaceCapture.postMessage(body);
  const enableSave = () => { saveButton.disabled = state !== 'ready' || !nameField.value.trim(); };
  window.setCaptureState = update => {
    state = update.state;
    document.getElementById('status').textContent = update.message;
    nameField.disabled = state !== 'ready';
    enableSave();
    if (state === 'ready') nameField.focus();
  };
  nameField.addEventListener('input', enableSave);
  document.getElementById('capture-form').addEventListener('submit', event => {
    event.preventDefault();
    if (state !== 'ready' || saveButton.disabled) return;
    window.setCaptureState({ state: 'saving', message: 'Saving the frozen snapshot…' });
    post({ action: 'save', name: nameField.value });
  });
  document.getElementById('cancel').addEventListener('click', () => post({ action: 'cancel' }));
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); post({ action: 'cancel' }); }
  });
  // Let the disabled form paint before starting the accessibility queries.
  requestAnimationFrame(() => requestAnimationFrame(() => post({ action: 'capture' })));
</script></body></html>]=]

function dialog.open(screenFrame, callbacks)
  local session = { state = "capturing", closed = false, started = false }
  local content = hs.webview.usercontent.new("TheseusWorkspaceCapture")
  session.content = content

  function session:setState(state, message)
    if self.closed then return end
    self.state = state
    self.view:evaluateJavaScript("window.setCaptureState(" .. hs.json.encode({
      state = state, message = message,
    }) .. ");")
  end

  function session:ready(message) self:setState("ready", message) end
  function session:failed(message) self:setState("failed", message) end

  local function finish(deleteView)
    if session.closed then return end
    session.closed = true
    session.state = "closed"
    if session.timer then session.timer:stop(); session.timer = nil end
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
    if session.closed or type(body) ~= "table" then return end
    if body.action == "cancel" then
      session:close()
    elseif body.action == "capture" and not session.started then
      session.started = true
      session.timer = hs.timer.doAfter(0.05, function()
        session.timer = nil
        if session.closed then return end
        local ok, err = pcall(callbacks.capture, session)
        if not ok then session:failed("Capture failed: " .. tostring(err)) end
      end)
    elseif body.action == "save" and session.state == "ready"
      and type(body.name) == "string" then
      session:setState("saving", "Saving the frozen snapshot…")
      local ok, err = pcall(callbacks.save, session, body.name)
      if not ok then session:ready("Save failed: " .. tostring(err)) end
    end
  end)

  local width, height = 480, 330
  session.view = hs.webview.new({
    x = screenFrame.x + (screenFrame.w - width) / 2,
    y = screenFrame.y + (screenFrame.h - height) / 2,
    w = width, h = height,
  }, {
    privateBrowsing = true,
    javaScriptCanOpenWindowsAutomatically = false,
    developerExtrasEnabled = false,
  }, content)
  session.view
    :windowStyle({ "titled", "closable" })
    :windowTitle("Capture workspace")
    :allowTextEntry(true)
    :closeOnEscape(true)
    :deleteOnClose(true)
    :policyCallback(function(action, _, details)
      if action == "navigationAction" then
        local url = details and details.request and details.request.URL
        -- LuaSkin converts NSURL to { __luaSkinType = "NSURL", url = ... }.
        if type(url) == "table" then return url.url == "about:blank" end
        return url == nil or url == "about:blank"
      end
      return action == "navigationResponse"
    end)
    :windowCallback(function(action)
      if action == "closing" then finish(false) end
    end)
    :html(html)
    :show()
    :bringToFront()
  return session
end

return dialog
