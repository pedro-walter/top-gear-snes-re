dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local hist={} local nf=0
emu.addMemoryCallback(function(a)
  nf=nf+1
  if nf%16==0 and R.f>=3300 and R.f<3400 then hist[a]=(hist[a] or 0)+1 end
end, emu.callbackType.exec, 0, 0xFFFFFF)
R.run(3400,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
end,function()
  local t={} for k,v in pairs(hist) do t[#t+1]={k,v} end table.sort(t,function(a,b) return a[2]>b[2] end)
  for i=1,30 do if t[i] then print(string.format("%06X %d",t[i][1],t[i][2])) end end
  for _,a in ipairs({0x1BB4,0x1BB6,0x1BB8,0x1BBA,0x1BBC,0x1BBE,0x1BC0,0x1BC2,0x1BC4,0x1BE6}) do print(string.format("%04X=%04X",a,rw(a))) end
end)
