-- experiment: run seed S on the randomizer ROM, optionally modify WRAM tables after load, screenshot a few frames.  env: SEED, EXP (none|noobj|noscen), SHOTS
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local EXP=os.getenv("EXP") or "none"
local TAG=os.getenv("TAG") or "exp"
local shots={}
for s in (os.getenv("SHOTS") or "3550"):gmatch("%d+") do shots[tonumber(s)]=true end
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
R.run(tonumber(os.getenv("MAXF") or 3700),function(f)
  if f<=2 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==3050 or f==3051 then
    if EXP=="noobj" then for a=0x6400,0x6FFF do emu.write(a,0,wr) end end
    if EXP=="flat" then for a=0x4000,0x4BFF do emu.write(a,0,wr) end for a=0x4C00,0x57FF do emu.write(a,0,wr) end end
  end
  if shots[f] then local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/%s_%d.png",TAG,f),"wb") fh:write(emu.takeScreenshot()) fh:close() end
end)
