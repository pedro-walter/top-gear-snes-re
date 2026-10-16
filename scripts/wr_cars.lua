dofile("./scripts/common.lua")
local lo,hi=tonumber(arg1 or "0x202"),0
local seen={}
local function cb(a,v)
  if R.f<3100 then return end
  local pc=R.pc()
  local k=string.format("%06X",pc)
  local e=seen[k] if not e then e={n=0,addrs={}} seen[k]=e end
  e.n=e.n+1
  local off=(a-0x202)%18
  e.addrs[off]=(e.addrs[off] or 0)+1
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x000202, 0x00036F)
R.steer=function(f) return {x=true} end
R.run(3500,nil,function()
  for k,e in pairs(seen) do
    local s={}
    for o,n in pairs(e.addrs) do s[#s+1]=string.format("+%d:%d",o,n) end
    table.sort(s)
    print("W",k,e.n,table.concat(s," "))
  end
end)
