dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local seen={}
local function cb(a,v)
  if R.f<1700 then return end
  local pc=R.pc()
  local reg=(a>>10)
  local k=string.format("%06X reg%05X",pc,a>>9<<9)
  local e=seen[k] if not e then e={n=0,first=R.f,last=R.f} seen[k]=e end
  e.n=e.n+1 e.last=R.f
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x7E3500, 0x7EFFFF)
R.steer=function(f) return {x=true} end
R.run(3000,nil,function()
  for k,e in pairs(seen) do print("W",k,e.n,e.first,e.last) end
end)
