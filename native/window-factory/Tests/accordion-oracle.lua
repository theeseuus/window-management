-- Execute the original Spoon callback with fake windows; no desktop operations.
local binding,focused,screen,windows
local function copy(f) return {x=f.x,y=f.y,w=f.w,h=f.h} end
hs={eventtap={event={types={}}},keycodes={map={}},printf=function() end,
 hotkey={bind=function(mods,key,callback) if key=='s' and #mods==4 then binding=callback end end},
 geometry={rect=copy},alert={closeAll=function() end,show=function() end},
 screen={mainScreen=function() return screen end},
 window={focusedWindow=function() return focused end,switcher={new=function() return {ui={}} end},filter={new=function() return {setOverrideFilter=function() end} end}}}
local spoon=dofile(arg[1]..'/Hammerspoon/TheseusWindow.spoon/init.lua');spoon:bindHotkeys()
local function json(f) return string.format('{"x":%g,"y":%g,"w":%g,"h":%g}',f.x,f.y,f.w,f.h) end
local cases={}
for _,sf in ipairs({{x=0,y=24,w=1440,h=876},{x=-1600,y=-900,w=1300,h=1800}}) do
 screen={frame=function() return sf end}
 for _,base in ipairs({{x=sf.x+60,y=sf.y+60,w=500,h=400},{x=sf.x+1000,y=sf.y+700,w=500,h=400},{x=sf.x-20,y=sf.y-40,w=1600,h=2000}}) do
  windows={}
  local function window(id,f)
   local current=copy(f)
   return {id=function() return id end,isStandard=function() return true end,isVisible=function() return true end,
    frame=function() return copy(current) end,setFrame=function(_,v) current=copy(v) end,screen=function() return screen end,
    application=function() return {allWindows=function() return windows end} end,focus=function() end}
  end
  focused=window(1,base)
  windows={focused,window(2,{x=200,y=90,w=10,h=10}),window(3,{x=100,y=40,w=20,h=20}),window(4,{x=100,y=90,w=30,h=30})}
  binding()
  cases[#cases+1]='{"screen":'..json(sf)..',"anchor":'..json(base)..',"expected":['..json(windows[2]:frame())..','..json(windows[3]:frame())..','..json(windows[4]:frame())..']}'
 end
end
io.write('['..table.concat(cases,',')..']\n')
