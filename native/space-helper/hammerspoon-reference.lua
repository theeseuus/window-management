-- Read-only baseline. Does not touch recipes, bindings, timers, or Spoon state.
local outputPath = assert(..., 'pass a temporary output path to this loaded chunk')
local before = hs.spaces.focusedSpace()
local out = {schemaVersion=1, focusedSpaceID=tostring(before), displays={}, windows={}}
for _, screen in ipairs(hs.screen.allScreens()) do
  local display = {display=screen:getUUID(), activeSpaceID=tostring(hs.spaces.activeSpaceOnScreen(screen)), spaces={}}
  for _, sid in ipairs(assert(hs.spaces.spacesForScreen(screen))) do
    local ids = {}
    for _, wid in ipairs(assert(hs.spaces.windowsForSpace(sid))) do ids[#ids+1]=tostring(wid) end
    display.spaces[#display.spaces+1]={id=tostring(sid), type=assert(hs.spaces.spaceType(sid)), windowIDs=ids}
  end
  out.displays[#out.displays+1]=display
end
for _, window in ipairs(hs.window.allWindows()) do
  if window:isStandard() then
    local ids = {}
    for _, sid in ipairs(assert(hs.spaces.windowSpaces(window:id()))) do ids[#ids+1]=tostring(sid) end
    out.windows[#out.windows+1]={windowID=tostring(window:id()), spaceIDs=ids}
  end
end
out.stable=before==hs.spaces.focusedSpace()
local file=assert(io.open(outputPath,'w'))
file:write(assert(hs.json.encode(out))); file:close()
print('NATIVE HELPER REFERENCE', #out.displays, #out.windows, out.stable)
