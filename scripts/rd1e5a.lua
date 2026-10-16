dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local seen={}
emu.addMemoryCallback(function(a,v)
  if R.f<3100 then return end
  local pc=R.pc(); seen[pc]=(seen[pc] or 0)+1
end, emu.callbackType.read, 0x001E5A, 0x001E5B)
R.steer=function(f) return {x=true} end
R.run(3500,nil,function() for k,n in pairs(seen) do print(string.format("R %06X %d",k,n)) end end)
