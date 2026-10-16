-- try to pit with the human car.  env: SEED (hex), DIR (left|right), MAXF
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "1",16)
local DIR=os.getenv("DIR") or "left"
local MAXF=tonumber(os.getenv("MAXF") or 9000)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local last=-1
R.steer=function(f)
  local pos=rw(0x1ED7)  -- note: odd aligned word; use car record instead
  local slot=rw(0x204)
  local prog=rw(0x1ED7)
  local pit=rw(0x1EF0)
  local lat=sw(rw(0x1E8A))
  local t={x=true}
  local d=(prog-(pit-1500))%rw(0x200)
  local target=tonumber(os.getenv("TARGET") or "15800")
  if d<3600 then
    if lat<target-300 then t.right=true elseif lat>target+300 then t.left=true end
  else
    if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  end
  return t
end
local SH0=tonumber(os.getenv('SH0') or 0) local SH1=tonumber(os.getenv('SH1') or 0)
R.run(MAXF,function(f)
  if f>=SH0 and f<=SH1 and f%20==0 then local fh=io.open(os.getenv('TG_ROOT')..'/out/pit_'..string.format('%X',SEED)..'_'..f..'.png','wb') fh:write(emu.takeScreenshot()) fh:close() end
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F806,0xA55A) end
  if f>3000 and (f%200==0 or (f>5700 and f<6100 and f%25==0)) then local slot=rw(0x204) print(string.format('f=%d prog=%d p1ed7=%d pit=%d lat=%d speed=%d st=%04X',f,rw(0x200+slot+7),rw(0x1ED7),rw(0x1EF0),sw(rw(0x1E8A)),rw(0x1E5A),rw(0x1E86))) end
  if f>3000 then
    local st=rw(0x1E86)
    if st~=last then
      local slot=rw(0x204) local prog=rw(0x200+slot+7)
      print(string.format("f=%d pit_state_p1=%04X prog=%d pit_pos=%d lat=%d fuel=%04X flags1EB4=%04X pit_mode40=%04X",f,st,prog,rw(0x1EF0),sw(rw(0x1E8A)),rw(0x1E62),rw(0x1EB4),rw(0x40)))
      last=st
    end
  end
end)
