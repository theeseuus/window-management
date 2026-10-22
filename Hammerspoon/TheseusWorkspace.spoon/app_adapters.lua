-- Canonical app-specific Establish operations. Add entries here, not shortcuts
-- or special cases in the placement engine. See docs/app-adapters.md in the
-- repository root for the extension and verification procedure.
-- Scripts and menu selection rules are reviewed source; recipe data is never executable.
-- Read only Safari's File menu. Profiles rename New Window; the native default
-- marker chooses the user's default without storing or guessing a profile name.
local function safariWindowMenu(app)
  local root = hs.axuielement.applicationElement(app)
  local bar = root and root:attributeValue("AXMenuBar")
  local function children(element)
    return element and element:attributeValue("AXChildren") or {}
  end
  local defaults, ordinary = {}, {}
  for _, item in ipairs(children(bar)) do
    if item:attributeValue("AXTitle") == "File" then
      for _, menu in ipairs(children(item)) do
        for _, command in ipairs(children(menu)) do
          local identifier = command:attributeValue("AXIdentifier")
          local title = command:attributeValue("AXTitle")
          if type(title) == "string" and type(identifier) == "string" then
            if identifier:match("^New.*Window%?isDefaultProfile=true$") then
              table.insert(defaults, title)
            elseif identifier == "NewWindow" and title == "New Window" then
              table.insert(ordinary, title)
            end
          end
        end
      end
      break
    end
  end
  if #defaults == 1 then return { "File", defaults[1] } end
  if #defaults == 0 and #ordinary == 1 then return { "File", ordinary[1] } end
  -- An absent/ambiguous default is a safe failure, never another profile/tab.
end

return {
  ["com.superlogical.rex"] = {
    name = "Rex Beta",
    kind = "menu",
    menu = { "File", "New Window" },
  },
  ["com.mitchellh.ghostty"] = {
    name = "Ghostty",
    kind = "applescript",
    checkInstalled = function(info)
      local major, minor = tostring(info.CFBundleShortVersionString):match("^(%d+)%.(%d+)")
      if not major or (tonumber(major) < 1)
        or (tonumber(major) == 1 and tonumber(minor) < 3)
        or not info.OSAScriptingDefinition then
        return false, "ghostty-requires-applescript-1.3"
      end
      return true
    end,
    script = [[
tell application id "com.mitchellh.ghostty"
  set config to new surface configuration
  new window with configuration config
end tell]],
  },
  ["com.apple.finder"] = {
    name = "Finder",
    kind = "applescript",
    script = [[
tell application id "com.apple.finder"
  make new Finder window
end tell]],
  },
  ["com.apple.Safari"] = {
    name = "Safari",
    kind = "menu",
    menu = safariWindowMenu,
  },
  ["com.barebones.bbedit"] = {
    name = "BBEdit",
    kind = "applescript",
    script = [[
tell application id "com.barebones.bbedit"
  make new text window
end tell]],
  },
  ["com.google.Chrome"] = {
    name = "Chrome",
    kind = "applescript",
    script = [[
tell application id "com.google.Chrome"
  set createdWindow to make new window
  set URL of active tab of createdWindow to "about:blank"
end tell]],
  },
  -- These identifiers are not aliases. Use only the exact app in the recipe.
  ["com.openai.chat"] = {
    name = "ChatGPT",
    kind = "menu",
    menu = { "File", "New Window" },
  },
  ["com.openai.codex"] = {
    name = "OpenAI desktop",
    kind = "menu",
    menu = { "File", "New Window" },
  },
  -- New Chat is navigation, not an independent-window operation.
  ["com.anthropic.claudefordesktop"] = {
    name = "Claude",
    kind = "launch-only",
    reason = "claude-new-window-unavailable",
  },
  ["com.microsoft.Excel"] = {
    name = "Microsoft Excel",
    kind = "applescript",
    script = [[
tell application id "com.microsoft.Excel"
  make new workbook
end tell]],
  },
  ["com.microsoft.Word"] = {
    name = "Microsoft Word",
    kind = "applescript",
    script = [[
tell application id "com.microsoft.Word"
  make new document
end tell]],
  },
  -- The installed bundle identifier spells Powerpoint with a lower-case p.
  ["com.microsoft.Powerpoint"] = {
    name = "Microsoft PowerPoint",
    kind = "applescript",
    script = [[
tell application id "com.microsoft.Powerpoint"
  make new presentation
end tell]],
  },
  ["com.apple.iWork.Keynote"] = {
    name = "Keynote",
    kind = "applescript",
    script = [[
tell application id "com.apple.iWork.Keynote"
  make new document
end tell]],
  },
  ["com.apple.iWork.Pages"] = {
    name = "Pages",
    kind = "applescript",
    script = [[
tell application id "com.apple.iWork.Pages"
  make new document
end tell]],
  },
  ["com.apple.iWork.Numbers"] = {
    name = "Numbers",
    kind = "applescript",
    script = [[
tell application id "com.apple.iWork.Numbers"
  make new document
end tell]],
  },
  -- A viewer, never a message/compose window. Uses Accessibility, not scripting.
  ["com.apple.mail"] = {
    name = "Mail",
    kind = "menu",
    menu = { "File", "New Viewer Window" },
  },
}
