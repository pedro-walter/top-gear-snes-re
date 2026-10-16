dofile("./scripts/common.lua")
local function rb(a) return emu.read(a,emu.memType.snesMemory) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
R.steer=function(f) return {x=true} end
R.run(3300,function(f)
  if f%20==0 and f>=3000 then print(f,"spd",rw(0x1E5A),"g72",rw(0x1E72),"g74",rw(0x1E74),"7A",rw(0x1F7A),"7C",rw(0x1F7C),"EE8",rw(0x1EE8),"top",rw(0x1EE2),"F2",rw(0x1EF2)) end
end)
