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
  if adapter.kind == "applescript" then
    equal(type(adapter.script), "string", "fixed native script")
    equal(adapter.script:find('tell application id "' .. bundleID .. '"', 1, true) ~= nil, true, "script targets the registry's exact app")
    equal(adapter.script:find("activate", 1, true), nil, "never activate another project's window")
    equal(adapter.script:find("keystroke", 1, true), nil, "no generic keyboard fallback")
    equal(adapter.menu, nil, "one transport, not guessed fallbacks")
    equal(adapter.reason, nil, "no launch-only reason on a script")
  elseif adapter.kind == "menu" then
    if bundleID == "com.apple.Safari" then
      equal(type(adapter.menu), "function", "Safari resolves the native default-profile command")
    else
      equal(type(adapter.menu), "table", "fixed menu path")
      equal(#adapter.menu, 2, "precise menu path")
      equal(adapter.menu[1], "File", "app's File menu")
      equal(type(adapter.menu[2]), "string", "exact menu item")
      equal(adapter.menu[2] ~= "New Chat" and adapter.menu[2] ~= "New Message", true, "a window, not content navigation or composition")
    end
    equal(adapter.script, nil, "menu does not fall back to scripting")
    equal(adapter.reason, nil, "menu is not launch-only")
  else
    equal(type(adapter.reason), "string", "explicit additional-window limitation")
    equal(adapter.script, nil, "launch-only cannot create by script")
    equal(adapter.menu, nil, "launch-only cannot create by a guessed menu")
  end
end
equal(count, 16, "reviewed adapter catalog")
equal(adapters["com.apple.iCal"], nil, "Calendar creation remains unsupported")
equal(adapters["com.apple.Preview"], nil, "Preview creation remains unsupported")
equal(adapters["com.microsoft.PowerPoint"], nil, "never alias a differently cased identifier")
equal(adapters["com.apple.mail"].kind, "menu", "Mail needs Accessibility, not new Automation access")
equal(table.concat(adapters["com.apple.mail"].menu, "/"), "File/New Viewer Window", "Mail opens a viewer, never a draft")

equal(adapters["com.superlogical.rex"].kind, "menu", "Rex uses existing Accessibility access")
equal(table.concat(adapters["com.superlogical.rex"].menu, "/"), "File/New Window", "Rex creates a window rather than a session or tab")
equal(adapters["com.mitchellh.ghostty"].kind, "applescript", "Ghostty remains an independent fallback")


local previousHs = hs
local function ax(attributes)
  return { attributeValue = function(_, key) return attributes[key] end }
end
local function resolve(commands)
  local file = ax({ AXTitle = "File", AXChildren = { ax({ AXChildren = commands }) } })
  hs = { axuielement = { applicationElement = function()
    return ax({ AXMenuBar = ax({ AXChildren = {
      ax({ AXTitle = "History", AXChildren = {} }), file,
    } }) })
  end } }
  return adapters["com.apple.Safari"].menu({})
end
local function command(title, identifier) return ax({ AXTitle = title, AXIdentifier = identifier }) end
local nondefault = command("New Personal Window", "NewPersonalWindow?isDefaultProfile=false")
local default = command('New Work "review" Window', "NewWorkWindow?isDefaultProfile=true")
local resolved = resolve({ nondefault, default, command("New Private Window", "NewPrivateWindow") })
equal(table.concat(resolved, "/"), 'File/New Work "review" Window', "use the native default marker rather than a remembered profile name")
equal(resolve({ nondefault }), nil, "never substitute a non-default profile")
equal(resolve({ default, default }), nil, "ambiguous default fails closed")
equal(resolve({ command("New Chat", "NewChat"), command("New Tab", "NewTab") }), nil, "never substitute content or a tab")
equal(table.concat(resolve({ command("New Window", "NewWindow") }), "/"), "File/New Window", "profile-free Safari uses its genuine window command")
equal(resolve({ command("New Window", "unknown") }), nil, "unverified command identifier is not enough")
hs = previousHs

print(string.format("app_adapters: %d assertions passed", assertions))
