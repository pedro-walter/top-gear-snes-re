-- Lap lost on a collision at the finish line?  env: PP (player pos offset from the line, negative = before),
-- BP (other car pos, small = just after the line), BLAP (other car lap byte), SIDE (1 = car ahead in the list, -1 = behind), BSPD, F0
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local wr=emu.memType.snesWorkRam
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function w1(a,v) emu.write(a,v&0xFF,wr) end
local PP=tonumber(os.getenv("PP") or "-4") local BP=tonumber(os.getenv("BP") or "2")
local BLAP=tonumber(os.getenv("BLAP") or "1") local SIDE=tonumber(os.getenv("SIDE") or "1")
local PLAP=tonumber(os.getenv("PLAP") or "0") local BSPD=tonumber(os.getenv("BSPD") or "256") local F0=tonumber(os.getenv("F0") or "3600")
R.steer=function(f) return {x=true} end
R.run(F0+(tonumber(os.getenv("NF") or 40))+20,function(f)
  if f>=1000 and f<1500 and (os.getenv("TG_ROM") or ""):find("rando") then local S=tonumber(os.getenv("SEED") or "1",16) w2(0x1F800,S&0xFFFF) w2(0x1F802,(S>>16)&0xFFFF) w2(0x1F806,0xA55A) end
  local y=R.rw(0x204) local L=R.rw(0x200)
  if f==F0 then
    local o=y+18*SIDE
    local pp=(PP+L)%L
    w2(0x1ED7,pp) w2(0x219+y,pp) w1(0x21B+y,PLAP) w2(0x1E76,PLAP)
    w2(0x219+o,(BP+L)%L) w1(0x21B+o,BLAP) w2(0x21C+o,BSPD) w2(0x214+o,R.rw(0x1E8A)) w2(0x216+o,0)
    print("setup y="..y.." o="..o.." L="..L.." laps="..R.rd(0x1E56))
  end
  if f>=F0 and f<F0+(tonumber(os.getenv("NF") or 40)) then if os.getenv("V") then print(string.format("pc=%06X sp=%04X f=%d pos=%d lap=%04X lb=%d spd=%d L=%d",R.pc(),emu.getState()["cpu.sp"],f-F0,R.rw(0x1ED7),R.rw(0x1E76),R.rd(0x21B+y),R.rw(0x1E5A),R.rw(0x200))) end
    local y=R.rw(0x204)
    if f==F0+(tonumber(os.getenv("NF") or 40))-1 then print(string.format("RESULT PP=%d BP=%d SIDE=%d lap=%04X lapbyte=%d pos=%d spd=%d",PP,BP,SIDE,R.rw(0x1E76),R.rd(0x21B+y),R.rw(0x1ED7),R.rw(0x1E5A))) end
  end
end)
