-- Calls hook_hit1/hook_hit2 (src/hooks.asm, 13:8000 / 13:800A) directly inside a running race and prints the returned position.
-- env: WHO=1|2  OWN=own position  OPOS=other position  OLAP=other lap byte minus own (0,1,255)
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local wr=emu.memType.snesWorkRam
local WHO=tonumber(os.getenv("WHO") or "2") local OWN=tonumber(os.getenv("OWN")) local OPOS=tonumber(os.getenv("OPOS")) local OLAP=tonumber(os.getenv("OLAP") or "0")
local RET=0x13F000
local function w(a,v) emu.write(a,v&0xFF,wr) end
local function w2(a,v) w(a,v) w(a+1,v>>8) end
R.steer=function(f) return {x=true} end
local armed=false
emu.addMemoryCallback(function()
  local st=emu.getState()
  local L=R.rw(0x200) local r=st["cpu.a"] print(string.format("RESULT L=%d who=%d own=%d other=%d dlap=%d -> %d (%s)",L,WHO,OWN,OPOS,OLAP,r,r>=L-0 and (r-65536) or r))
  emu.stop(0)
end, emu.callbackType.exec, RET)
R.run(4000,function(f)
  if f==3700 and not armed then armed=true
    local L=R.rw(0x200)
    if OWN<0 then OWN=L+OWN end if OPOS<0 then OPOS=L+OPOS end   -- negative = distance before the line
    local y=R.rw(WHO==2 and 0x206 or 0x204) local x=(y+18)%0x100
    w2(0x219+y,OWN) w(0x21B+y,5) w2(0x219+x,OPOS) w(0x21B+x,(5+OLAP)&0xFF)
    local s=emu.getState()
    local sp=s["cpu.sp"]-3
    local r=(RET&0xFFFF)-1
    w(sp+1,r&0xFF) w(sp+2,r>>8) w(sp+3,0x13)
    s["cpu.sp"]=sp s["cpu.k"]=0x13 s["cpu.dbr"]=0x00 s["cpu.pc"]=(WHO==2) and 0x800A or 0x8000
    s["cpu.a"]=OPOS s["cpu.x"]=x s["cpu.y"]=y
    s["cpu.ps"]=s["cpu.ps"] & ~0x30
    emu.setState(s)
  end
end)
