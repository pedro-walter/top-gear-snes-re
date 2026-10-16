dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
R.steer=function(f) return {} end
R.run(3000,function(f)
  if f>=1500 and f<2900 then emu.write(0x1F06,TRACK,mt) end
  if f>=1700 and f<2900 and f%50==0 then
    local fh=io.open(string.format("./out/tm_%d_%d.png",TRACK,f),"wb")
    fh:write(emu.takeScreenshot()) fh:close()
  end
end)
