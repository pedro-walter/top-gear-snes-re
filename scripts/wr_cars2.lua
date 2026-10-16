dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local seen={}
local function cb(a,v)
  if R.f<(tonumber(os.getenv("MINF") or 2900)) then return end
  local pc=R.pc()
  local fld=(a-0x212)%18
  local j=(a-0x212)//18
  local k=string.format("%06X f%02X",pc,fld)
  local e=seen[k] if not e then e={n=0,ex={}} seen[k]=e end
  e.n=e.n+1
  if #e.ex<6 and (fld>=4 and fld<=15) then e.ex[#e.ex+1]=string.format("f%d:j%d=%04X",R.f,j,v) end
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x000212, 0x00036F)
R.steer=function(f) local ph=(f//50)%2 local t={x=true} if ph==0 then t.left=true else t.right=true end return t end
R.run(tonumber(os.getenv("MAXF") or 4000),nil,function()
  for k,e in pairs(seen) do
    print("W",k,e.n,table.concat(e.ex," "))
  end
end)
