local path = debug.getinfo(1, "S").source:match("^@(.*/)")
local root = path:match("^(.*)/tests/$")
local adapters = dofile(root .. "/Hammerspoon/TheseusWorkspace.spoon/app_adapters.lua")
local assertions = 0
local function equal(actual, expected, label)
  assertions = assertions + 1
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local count = 0
for bundleID, adapter in pairs(adapters) do
  count = count + 1
  equal(type(bundleID), "string", "exact application identifier")
  equal(type(adapter.name), "string", "readable adapter label")
  equal(adapter.name ~= "", true, "nonempty adapter label")
  equal(adapter.kind == "applescript" or adapter.kind == "menu" or adapter.kind == "launch-only", true, "known transport")
  equal(adapter.checkInstalled == nil or type(adapter.checkInstalled) == "function", true, "optional installed-metadata check")
  equal(adapter.resultKind == nil or adapter.resultKind == "window-id", true, "optional native identity receipt")
  equal(adapter.navigationScript == nil or type(adapter.navigationScript) == "function", true, "optional fixed new-window navigation")
  if adapter.navigationScript then
    equal(adapter.resultKind, "window-id", "navigation requires an explicit native identity receipt")
  end
  if adapter.kind == "applescript" then
    equal(type(adapter.script), "string", "fixed native script")
    equal(adapter.script:find('tell application id "' .. bundleID .. '"', 1, true) ~= nil, true, "script targets the registry's exact app")
    equal(adapter.script:find("activate", 1, true), nil, "never activate another project's window")
    equal(adapter.script:find("keystroke", 1, true), nil, "no generic keyboard fallback")
    equal(adapter.menu, nil, "one transport, not guessed fallbacks")
    equal(adapter.reason, nil, "no launch-only reason on a script")
  elseif adapter.kind == "menu" then
    equal(type(adapter.menu), "table", "fixed menu path")
    equal(#adapter.menu, 2, "precise menu path")
    equal(adapter.menu[1], "File", "app's File menu")
    equal(type(adapter.menu[2]), "string", "exact menu item")
    equal(adapter.menu[2] ~= "New Chat" and adapter.menu[2] ~= "New Message", true, "a window, not content navigation or composition")
    equal(adapter.script, nil, "menu does not fall back to scripting")
    equal(adapter.reason, nil, "menu is not launch-only")
  else
    equal(type(adapter.reason), "string", "explicit additional-window limitation")
    equal(adapter.script, nil, "launch-only cannot create by script")
    equal(adapter.menu, nil, "launch-only cannot create by a guessed menu")
  end
end
equal(count, 15, "reviewed adapter catalog")
equal(adapters["com.apple.iCal"], nil, "Calendar creation remains unsupported")
equal(adapters["com.apple.Preview"], nil, "Preview creation remains unsupported")
equal(adapters["com.microsoft.PowerPoint"], nil, "never alias a differently cased identifier")
equal(adapters["com.apple.mail"].kind, "menu", "Mail needs Accessibility, not new Automation access")
equal(table.concat(adapters["com.apple.mail"].menu, "/"), "File/New Viewer Window", "Mail opens a viewer, never a draft")

print(string.format("app_adapters: %d assertions passed", assertions))
