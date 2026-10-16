dofile("./scripts/common.lua")
local lo=tonumber(os.getenv("LO")) local hi=tonumber(os.getenv("HI") or os.getenv("LO"))
local f0=tonumber(os.getenv("F0") or 3100)
local seen={}
local kind=os.getenv("KIND") or "write"
emu.addMemoryCallback(function(a,v)
  if R.f<f0 then return end
  local pc=R.pc()
  local k=string.format("%06X",pc)
  local e=seen[k] if not e then e={n=0,ex={}} seen[k]=e end
  e.n=e.n+1
  if #e.ex<4 then e.ex[#e.ex+1]=string.format("f%d@%04X=%02X",R.f,a&0xFFFF,v) end
end, emu.callbackType[kind], lo, hi)
R.steer=function(f) local ph=(f//50)%2 local t={x=true} if ph==0 then t.left=true else t.right=true end return t end
R.run(tonumber(os.getenv("MAXF") or 3600),nil,function()
  for k,e in pairs(seen) do print("W",k,e.n,table.concat(e.ex," ")) end
end)
