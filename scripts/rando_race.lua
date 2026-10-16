-- Drive a race on the randomizer ROM (out/rando.sfc).  env: SEED (hex), STEP, MAXF, TAG
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local STEP=tonumber(os.getenv("STEP") or 300)
local MAXF=tonumber(os.getenv("MAXF") or 9000)
local TAG=os.getenv("TAG") or string.format("%08X",SEED)
local log=io.open(os.getenv("TG_ROOT").."/out/race_"..TAG..".txt","w")
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f)
  local lat=sw(rw(0x1E8A))
  local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF)
R.run(MAXF,function(f)
  if os.getenv('TRACK') and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv('TRACK')),mt) end
  if f<=2 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) end
  if f>=3100 and (f-3100)%STEP==0 then
    local pos=emu.read(0x1ED7,mt)|(emu.read(0x1ED8,mt)<<8)
    local sp=emu.read(0x1E5A,mt)|(emu.read(0x1E5B,mt)<<8)
    local laps=emu.read(0x1E56,mt)|(emu.read(0x1E57,mt)<<8)
    local trk=emu.read(0x1F06,mt)
    local len=emu.read(0x200,mt)|(emu.read(0x201,mt)<<8)
    local pc=R.pc()
    local slot=rw(0x204)
    local lap=emu.read(0x200+slot+9,mt) local prog=rw(0x200+slot+7)
    log:write(string.format("%d prog=%d speed=%d laps=%d lap=%d lat=%d rank=%d fuel=%04X pit=%04X fin=%d track=%d len=%d pc=%06X\n",f,prog,sp,laps,lap,sw(rw(0x1E8A)),rw(0x1E7A),rw(0x1E62),rw(0x1E86),rw(0x1EB0),trk,len,pc))
    if not os.getenv("NOSHOT") then local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/race_%s_%05d.png",TAG,f),"wb")
    fh:write(emu.takeScreenshot()) fh:close() end
  end
end,function() log:close() end)
