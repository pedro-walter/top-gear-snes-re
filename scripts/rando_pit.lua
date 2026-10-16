-- log the computer car's fuel and pit state during a long race.  env: SEED, MAXF
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "1",16)
local MAXF=tonumber(os.getenv("MAXF") or 20000)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local last88=-1
R.run(MAXF,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F806,0xA55A) end
  local p=rw(0x1E88)
  if f>3000 and p~=last88 then print(string.format("f=%d pit_state_p2=%04X fuel_p2=%04X fuel_p1=%04X ai=%04X pit_pos=%04X",f,p,rw(0x1E64),rw(0x1E62),rw(0x1EF2),rw(0x1EF0))) last88=p end
  if f>3000 and f%2000==0 then print(string.format("f=%d fuel_p2=%04X fuel_p1=%04X lap_total=%d",f,rw(0x1E64),rw(0x1E62),rw(0x1E56))) end
end)
