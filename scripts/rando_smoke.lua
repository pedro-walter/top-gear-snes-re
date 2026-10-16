-- smoke test: seed S, autopilot, check the game keeps running at full speed.  Prints one line "SMOKE ..."
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "1",16)
local MAXF=tonumber(os.getenv("MAXF") or 5200)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local minspeed=99999
R.run(MAXF,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>=4600 then local sp=rw(0x1E5A) if sp<minspeed then minspeed=sp end end
end,function()
  local s=emu.getState()
  print(string.format("SMOKE seed=%08X env=%d len=%d laps=%d race_frames=%d speed=%d minspeed=%d pc=%02X:%04X",SEED,emu.read(0x1F06,mt),rw(0x200),rw(0x1E56),rw(0x1EAE),rw(0x1E5A),minspeed,s["cpu.k"],s["cpu.pc"]))
end)
