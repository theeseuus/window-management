local canonical = dofile(assert(arg[1]) .. '/Hammerspoon/TheseusWindow.spoon/canonical_layout.lua')
local function frame(f) return string.format('{"x":%.17g,"y":%.17g,"w":%.17g,"h":%.17g}',f.x,f.y,f.w,f.h) end
local screens={{x=0,y=24,w=1440,h=876},{x=-1500,y=-800,w=1300,h=1800},{x=2400,y=200,w=1000,h=1200}}
local shapes={{x=0,y=0,w=.5,h=1},{x=.5,y=0,w=.5,h=.5},{x=.31,y=.29,w=.44,h=.42},{x=0,y=.8,w=.7,h=.9},{x=.75,y=.5,w=.25,h=.5},{x=.5,y=.5,w=.25,h=.25},{x=.1,y=.1,w=1,h=1},{x=.25,y=0,w=.5,h=1}}
local cases={}
for _,s in ipairs(screens) do
 for _,n in ipairs(shapes) do
  local f={x=s.x+n.x*s.w,y=s.y+n.y*s.h,w=n.w*s.w,h=n.h*s.h}
  for _,c in ipairs({{'sizeNext','sizeCycle',1},{'sizePrevious','sizeCycle',-1},{'positionNext','positionCycle',1},{'positionPrevious','positionCycle',-1}}) do
   local result=assert(canonical[c[2]](f,s,c[3]))
   cases[#cases+1]='{"command":"'..c[1]..'","frame":'..frame(f)..',"screen":'..frame(s)..',"expected":'..frame(result)..'}'
  end
 end
end
io.write('['..table.concat(cases,',')..']\n')
