dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local out=io.open(os.getenv("TG_ROOT").."/out/vramw5.txt","w")
local seen={}
local function pcs() local s=emu.getState() return (s["cpu.k"]<<16)|s["cpu.pc"] end
local function lg(name) return function(addr,val)
  if (R.f>=1536 and R.f<=1542) or (R.f>=2356 and R.f<=2361) then
    local pc=pcs(); local key=R.f..name..string.format("%06X",pc)
    if not seen[key] then seen[key]=true out:write(string.format("f=%d %s pc=%06X first val=%02X\n",R.f,name,pc,val)) end end end end
for _,n in ipairs({0x2118,0x2119,0x2115,0x2116,0x2117,0x2139,0x213A}) do
  emu.addMemoryCallback(lg(string.format("%04X",n)), emu.callbackType.write, n)
end
R.steer=function(f) return {} end
R.run(2365,nil,function() out:close() end)
