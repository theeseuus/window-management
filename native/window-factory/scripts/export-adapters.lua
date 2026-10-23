-- Build-only bridge from the unchanged canonical Lua registry to native JSON.
local adapters = assert(loadfile(assert(arg[1])))()
local function quote(s)
  return '"' .. s:gsub('[%z\1-\31\\"]',function(c)
    if c=='\\' then return '\\\\' end
    if c=='"' then return '\\"' end
    return string.format('\\u%04x',string.byte(c))
  end) .. '"'
end
local keys={}; for id in pairs(adapters) do keys[#keys+1]=id end; table.sort(keys)
local out={}
for _,id in ipairs(keys) do
  local a=adapters[id]
  local fields={'"bundleID":'..quote(id),'"name":'..quote(a.name),'"kind":'..quote(a.kind)}
  for _,key in ipairs({'script','reason','placementPolicy'}) do
    if a[key] then fields[#fields+1]=quote(key)..':'..quote(a[key]) end
  end
  if type(a.menu)=='table' then fields[#fields+1]='"menu":['..quote(a.menu[1])..','..quote(a.menu[2])..']' end
  if type(a.menu)=='function' then
    assert(id=='com.apple.Safari','Unported dynamic menu selector')
    fields[#fields+1]='"selector":"safari-default-profile"'
  end
  if a.checkInstalled then
    assert(id=='com.mitchellh.ghostty','Unported installed check')
    fields[#fields+1]='"requirement":"ghostty-applescript-1.3"'
  end
  out[#out+1]='  {'..table.concat(fields,',')..'}'
end
io.write('{"schemaVersion":1,"adapters":[\n'..table.concat(out,',\n')..'\n]}\n')
