dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local out=io.open(os.getenv("TG_ROOT").."/out/marker.txt","w")
local seen={}
local function pcs() local s=emu.getState() return (s["cpu.k"]<<16)|s["cpu.pc"] end
local function lg(a) return function(addr,val)
  if R.f>=2500 and R.f<3400 then
    local pc=pcs() local k=string.format("%04X%06X",a,pc)
    if not seen[k] then seen[k]=true out:write(string.format("f=%d W %04X=%02X pc=%06X\n",R.f,a,val,pc)) end end end end
for a=0x156A,0x1575 do emu.addMemoryCallback(lg(a), emu.callbackType.write, a) end
for a=0x134A,0x1355 do emu.addMemoryCallback(lg(a), emu.callbackType.write, a) end
R.steer=function(f) return {x=true} end
R.run(3405,function(f) if f>=2000 and f<2400 then emu.write(0x1F06,0,mt) end end,function() out:close() end)
