dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local n=0
emu.addMemoryCallback(function(a,v)
  if R.f<3000 then return end
  n=n+1
  if n<400 and (n%20==0 or v>0x0F) then
    local s=emu.getState()
    print(string.format("f=%d W %04X <= %02X pc=%02X:%04X",R.f,a,v,s["cpu.k"],s["cpu.pc"]))
  end
end, emu.callbackType.write, 0x1BC2, 0x1BC5)
emu.addMemoryCallback(function(a,v) if R.f<3000 then return end n=n+1 if n<400 and (n%20==0 or v>0x0F) then local s=emu.getState() print(string.format("f=%d W7E %04X <= %02X pc=%02X:%04X",R.f,a,v,s["cpu.k"],s["cpu.pc"])) end end, emu.callbackType.write, 0x7E1BC2, 0x7E1BC5)
R.run(3400,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
end)
