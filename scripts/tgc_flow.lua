-- Drives the TGC tournament ROM (docs/18): title -> TRACK row of the main menu -> adds the tracks in TRACKS (A button) -> PLAY GAME,
-- then forces the end of RACES races (jump to race_exit 00:8834 with a forged finish list, like race_end_force.lua) and prints the
-- tournament state (7F:2400.. block) at every step of the results flow. Frames of interest are saved as out/<TAG>_<frame>.png.
-- usage: TG_ROM="Top Gear TGC Rom (E) [!].smc" TRACKS="0,5,10,15" RACES=4 PLACES="0,3,9,1," MAXF=12500 SHOTS="5000,6000" TAG=tgc tools/mesen.sh scripts/tgc_flow.lua
--   TRACKS ascending or not (the script walks Left/Right between them), "x" = no tracks (stock behaviour), PSHOTS=1 = a shot every 30 frames after each force.
-- Timing (frames): splash skipped at 700, title Start presses 1100..1700, options menu usable from ~2440.
local OUT=(os.getenv("TG_ROOT") or ".").."/out/"..(os.getenv("TAG") or "tgc")
local E=function(k,d) return tonumber(os.getenv(k) or d) end
local PLACE=E("PLACE",0) local MAXF=E("MAXF",6000) local HOLD=20
local wr=emu.memType.snesWorkRam local mt=emu.memType.snesMemory
local function w(a,v) emu.write(a,v,mt) end
local function r(a) return emu.read(a,mt) end
local function rw(a) return r(a)|(r(a+1)<<8) end
local sched={}
local function press(f,b) for i=0,HOLD do sched[f+i]=b end end
for f=700,700 do press(f,"start") end
for f=1100,1700,60 do press(f,"start") end
local f=2440
local function key(b) press(f,b) f=f+60 end
key("down") key("down") key("down")
local cur=0
for t in (os.getenv("TRACKS") or "0,1,2,3"):gmatch("%d+") do
  t=tonumber(t)
  while cur<t do key("right") cur=cur+1 end
  while cur>t do key("left") cur=cur-1 end
  key("a")
end
key("down") key("a")
PLAYF=f
FR=0 forced=0
local shots={}
for s in (os.getenv("SHOTS") or ""):gmatch("%d+") do shots[tonumber(s)]=true end
emu.addEventCallback(function()
  local p={} local b=sched[FR] if b then p[b]=true end
  if forced>0 and FR>forced+60 and (FR%90)<8 then p.a=true end
  if os.getenv("PAUSEA") and FR>=tonumber(os.getenv("PAUSEA")) and FR%90<8 then p.a=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
local function st(tag)
  local g=function(a) return emu.read(a,wr) end
  local gw=function(a) return g(a)|(g(a+1)<<8) end
  local lst={} for i=0,math.min(gw(0x12408),33)-1 do lst[#lst+1]=g(0x1240A+2*i) end
  print(string.format("%s f=%d 1F06=%d 1F04=%d 1F00=%d 1F02=%d 1F10=%d | flag=%d idx=%d cnt=%d list=%s sv=%d,%d tot0=%d tot1=%d u=%04X", tag,FR,g(0x1F06),g(0x1F04),g(0x1F00),g(0x1F02),g(0x1F10),gw(0x12400),gw(0x12402),gw(0x12408),table.concat(lst,","),gw(0x12404),gw(0x12406),gw(0x12500),gw(0x12502),gw(0x1FB0)))
end
local function force()
  local ids={} local nxt=2
  for i=0,9 do if i==PLACE then ids[i]=0 else ids[i]=nxt nxt=nxt+1 end end
  for i=0,9 do w(0x1F12+i,ids[i]) end
  for i=0,19 do w(0x1F26+2*i,0) w(0x1F27+2*i,0) end
  for i=0,9 do local t=6000+i*20; w(0x1F26+2*ids[i],t&255); w(0x1F27+2*ids[i],t>>8) end
  w(0x1EB0,10); w(0x1EB1,0)
  w(0x1F00,PLACE&255); w(0x1F01,0); w(0x1F02,1); w(0x1F03,0)
  local s=emu.getState(); s["cpu.k"]=0; s["cpu.pc"]=0x8834; s["cpu.d"]=0; s["cpu.ps"]=s["cpu.ps"]&0xC7; s["cpu.dbr"]=0; s["cpu.sp"]=0x1FE; emu.setState(s)
  st("FORCE") 
end
nf=0
emu.addMemoryCallback(function() if nf<E("RACES",1) and FR>=(nf==0 and PLAYF+400 or forced+1500) then forced=FR nf=nf+1 PLACE=(os.getenv("PLACES") and tonumber(({os.getenv("PLACES"):match(string.rep("(%d+),?",nf))})[nf])) or PLACE force() end end, emu.callbackType.exec, 0x00877D, 0x00877D)
local marks={[0x0F83DD]="results_flow",[0x0F8442]="draw_points",[0x0F84A4]="qualify_check",[0x0F84AC]="advance_track",[0x0F8733]="advance_track_fn",[0x0F84C0]="WIN_COUNTRY",[0x0F818E]="main_menu",[0x0F815A]="location_screen",[0x0F8C95]="title_screen",[0x0F84CB]="FAIL_RACE",[0x0F8584]="msg0"}
for a,n in pairs(marks) do emu.addMemoryCallback(function() st(n) end, emu.callbackType.exec, a, a) end
emu.addEventCallback(function()
  FR=FR+1
  if shots[FR] then local fh=io.open(OUT.."_"..FR..".png","wb") fh:write(emu.takeScreenshot()) fh:close() st("SHOT") end
  if os.getenv("PSHOTS") and forced>0 and (FR-forced)%30==0 and (FR-forced)<=900 then local fh=io.open(OUT.."_p"..(FR-forced)..".png","wb") fh:write(emu.takeScreenshot()) fh:close() end
  if FR>=MAXF then st("END") emu.stop(0) end
end, emu.eventType.endFrame)
print("PLAYF",PLAYF)
