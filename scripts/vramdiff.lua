dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local vr=emu.memType.snesVideoRam
local TRACK=tonumber(os.getenv("TRACK") or 0)
local A0,A1=tonumber(os.getenv("A0") or 0x1220),tonumber(os.getenv("A1") or 0x1440)
local prev=""
local out=io.open("./out/vramdiff.txt","w")
R.steer=function(f) return {} end
R.run(3100,function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
  if f>=tonumber(os.getenv("F0") or 2400) then
    local t={}
    for a=A0,A1-1 do t[#t+1]=string.char(emu.read(a,vr)) end
    local s=table.concat(t)
    local nz=0 for i=1,#s do if s:byte(i)~=0 then nz=nz+1 end end
    if s~=prev then out:write(string.format("f=%d changed nonzero=%d\n",f,nz)) prev=s end
  end
end,function() out:close() end)
