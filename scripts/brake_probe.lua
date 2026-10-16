dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- probe brake-related state: masks, $0108, WRAM $1DDF.. while holding accelerate (+brake after f=3400)
local out=io.open(os.getenv("TG_ROOT").."/out/brake_probe.txt","w")
R.steer=function(f)
  local p={x=true}
  if f>=3400 then p.y=true end
  return p
end
R.run(3500,function(f)
  if f==3300 or f==3450 then
    local t={}
    for _,a in ipairs{0x1F76,0x1F78,0x1F7A,0x1F7C,0x1F7E,0x1F80,0x1F82,0x108,0x1DDF,0x1DE1,0x1DE3,0x1DE5,0x1DE7,0x1E5A,0x1E90,0x1EE8,0x1E92,0x1E94,0x1EF5} do t[#t+1]=string.format("%04X=%04X",a,R.rw(a)) end
    out:write(f.." "..table.concat(t," ").."\n")
  end
end,function() out:close() end)
