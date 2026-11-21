-- Rome championship: seed poked before race_init, dump bot ids/speeds/slots after the start ramp. Env SEED (hex or dec), FR
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local SEED=tonumber(os.getenv("SEED") or 0)
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local first=true
emu.addMemoryCallback(function() if first then first=false print("seed_at_init",R.rw(0x1FF4),"diff",R.rw(0x1F10),"track",R.rw(0x1F06),"p1slot",R.rw(0x204),"p2slot",R.rw(0x206)) end end, emu.callbackType.exec, 0x00A622, 0x00A622)
emu.addMemoryCallback(function() ww(0x1FF4,SEED) end, emu.callbackType.exec, 0x00A558, 0x00A558)
R.steer=function(f) return {x=true} end
R.run(3400,function(f)
  if f>=2000 and f<2400 then ww(0x1F06,25) ww(0x1F10,2) end
  if f==3300 then
    for j=0,19 do local b=0x212+18*j print("car",j,R.rw(b)&0x1F,R.rw(b+10),R.rw(b+7)) end
  end
end)
