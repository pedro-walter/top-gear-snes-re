dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local out=io.open(os.getenv("TG_ROOT").."/out/findoam.txt","w")
R.steer=function(f) return {x=true} end
R.run(3300,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,0,mt) end
  if f==3299 then
    local oam=emu.memType.snesSpriteRam
    local o={} for i=0,15 do o[i]=emu.read(i,oam) end
    out:write("oam0: "..table.concat(o,",").."\n")
    for a=0,0x1FFF do
      local ok=true
      for i=0,7 do if emu.read(a+i,mt)~=o[i] then ok=false break end end
      if ok then out:write(string.format("match WRAM %04X\n",a)) end
    end
  end
end,function() out:close() end)
