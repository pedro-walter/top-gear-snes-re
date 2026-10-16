dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
local STEP=tonumber(os.getenv("STEP") or 300)
local MAXF=tonumber(os.getenv("MAXF") or 9000)
local log=io.open(string.format("./out/drv_%d.txt",TRACK),"w")
R.steer=function(f) return {x=true} end
R.run(MAXF,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
  if f>=3100 and (f-3100)%STEP==0 then
    local pos=emu.read(0x1ED7,mt)|(emu.read(0x1ED8,mt)<<8)
    local sky=emu.read(0x112,mt)|(emu.read(0x113,mt)<<8)
    log:write(string.format("%d %d %d\n",f,pos,sky))
    local fh=io.open(string.format("./out/drv_%d_%05d.png",TRACK,f),"wb")
    fh:write(emu.takeScreenshot()) fh:close()
  end
end,function() log:close() end)
