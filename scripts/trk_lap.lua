dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
local STEP=tonumber(os.getenv("STEP") or 150)
local log=io.open(string.format("./out/lap/lap_%d.txt",TRACK),"w")
local maxpos,done=0,false
R.steer=function(f) return {x=true} end
R.run(14000,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
  if f>=3100 and (f-3100)%STEP==0 and not done then
    local pos=emu.read(0x1ED7,mt)|(emu.read(0x1ED8,mt)<<8)
    log:write(string.format("%d %d\n",f,pos))
    local fh=io.open(string.format("./out/lap/%d_%05d.png",TRACK,f),"wb")
    fh:write(emu.takeScreenshot()) fh:close()
    if f>=3500 and pos>maxpos then maxpos=pos end
    if f>=3500 and maxpos>20000 and pos<maxpos-8000 then done=true; emu.stop(0) end
  end
end,function() log:close() end)
