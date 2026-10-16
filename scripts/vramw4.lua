dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local out=io.open("./out/vramw4.txt","w")
local last2118pc,cnt=-1,0
local function pcs() local s=emu.getState() return (s["cpu.k"]<<16)|s["cpu.pc"] end
local function lg(name) return function(addr,val)
  if (R.f>=1520 and R.f<=1545) or (R.f>=2340 and R.f<=2362) then
    out:write(string.format("f=%d %s=%02X pc=%06X\n",R.f,name,val,pcs())) end end end
for _,b in ipairs({0x000000,0x800000}) do
  emu.addMemoryCallback(lg("2116"), emu.callbackType.write, b+0x2116)
  emu.addMemoryCallback(lg("2117"), emu.callbackType.write, b+0x2117)
  emu.addMemoryCallback(lg("420B"), emu.callbackType.write, b+0x420B)
end
R.steer=function(f) return {} end
R.run(2365,nil,function() out:close() end)
