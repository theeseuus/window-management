-- Canonical app-specific Establish operations. Add entries here, not shortcuts
-- or special cases in the placement engine. See docs/app-adapters.md in the
-- repository root for the extension and verification procedure.
-- Scripts and menu paths are fixed source; recipe data is never executable.
return {
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
    kind = "applescript",
    script = [[
tell application id "com.apple.Safari"
  make new document with properties {URL:"about:blank"}
end tell]],
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
