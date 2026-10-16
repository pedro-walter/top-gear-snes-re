dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
R.steer=function(f) return {} end
R.run(2320,function(f)
  if f>=1500 and f<2300 then emu.write(0x1F06,TRACK,mt) end
  if f==2300 then
    local fh=io.open(os.getenv("TG_ROOT").."/out/mapgfx_"..TRACK..".bin","wb")
    for a=0x7E2000,0x7E5FFF do fh:write(string.char(emu.read(a,mt))) end
    fh:close()
    local sh=io.open(os.getenv("TG_ROOT").."/out/mapgfx_"..TRACK..".png","wb") sh:write(emu.takeScreenshot()) sh:close()
  end
end)
