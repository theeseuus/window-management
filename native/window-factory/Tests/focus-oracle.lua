local logic=dofile(assert(arg[1])..'/Hammerspoon/TheseusWindow.spoon/spatial_focus_logic.lua')
local function f(v) return string.format('{"x":%.17g,"y":%.17g,"w":%.17g,"h":%.17g}',v.x,v.y,v.w,v.h) end
local function record(v) return '{"id":'..v.id..',"display":'..v.display..',"frame":'..f(v.frame)..'}' end
local cases={}
for _,scale in ipairs({0.5,1,2}) do
 for _,origin in ipairs({{0,0},{-1700,-300},{200,800}}) do
  for _,shape in ipairs({{100,100,100,100},{0,0,300,600},{55,20,60,90},{0,0,0,100}}) do
   local current={id=999,display=1,frame={x=origin[1]+shape[1]*scale,y=origin[2]+shape[2]*scale,w=shape[3]*scale,h=shape[4]*scale}}
   local candidates={}
   for j=0,24 do
    candidates[#candidates+1]={id=j+1,display=j%3==0 and 2 or 1,frame={x=origin[1]+(j%5)*90*scale-80*scale,y=origin[2]+math.floor(j/5)*90*scale-80*scale,w=80*scale,h=(j%2==0 and 80 or 140)*scale}}
   end
   candidates[#candidates+1]={id=100,display=1,frame={x=0,y=0,w=0,h=100}}
   for _,reverse in ipairs({false,true}) do
    if reverse then local t={} for j=#candidates,1,-1 do t[#t+1]=candidates[j] end candidates=t end
    for _,direction in ipairs({'left','down','up','right'}) do
     local same,encoded={},{}
     for _,v in ipairs(candidates) do if v.display==1 then same[#same+1]=v end encoded[#encoded+1]=record(v) end
     local winner=logic.nearest(current.frame,same,direction) or logic.nearest(current.frame,candidates,direction)
     cases[#cases+1]='{"current":'..record(current)..',"candidates":['..table.concat(encoded,',')..'],"direction":"'..direction..'","expected":'..(winner and winner.id or 'null')..'}'
    end
   end
  end
 end
end
io.write('['..table.concat(cases,',')..']\n')
