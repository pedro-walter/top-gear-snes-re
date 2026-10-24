-- usage: TAG=x PLACE=<0-based human race place> TRACK=<0..31> DIFF=<0..2> PTS="20 byte points, car id order" MAXF=<frames> tools/mesen.sh scripts/race_end_force.lua
-- Boots, starts a 1P race, then at frame 3300 jumps to race_exit (00:8834) with a forged finish list and watches the post-race flow
-- (results -> qualification -> message screen -> title). Screenshots every 30 frames after the force: out/TAG_<frames>.png. See docs/13.
local OUT=os.getenv("TG_ROOT").."/out/"
local E=function(k,d) return tonumber(os.getenv(k) or d) end
local PLACE=E("PLACE",0)       -- 0-based finishing place of the human
local TRACK=E("TRACK",0)
local DIFF=E("DIFF",0)
local PTS=os.getenv("PTS")     -- comma list of 20 points bytes
local MAXF=E("MAXF",4000)
local TAG=os.getenv("TAG") or "x"
local f=0
local forced=false
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local FORCE=3300
local function w(a,v) emu.write(a,v,emu.memType.snesMemory) end
local function r(a) return emu.read(a,emu.memType.snesMemory) end
local function rw(a) return r(a)|(r(a+1)<<8) end
local function shot(n) local fh=io.open(OUT..n..".png","wb") if fh then fh:write(emu.takeScreenshot()) fh:close() end end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>FORCE+60 and forced and (f%90)<6 then p.a=true end   -- poke A regularly to pass the wait-for-input screens
  emu.setInput(p,0)
end, emu.eventType.inputPolled)

local function force()

    w(0x1F06,TRACK); w(0x1F10,DIFF)
    -- finish list: 10 entries; human = car 0 at index PLACE, others ids 2..
    local ids={} local nxt=2
    for i=0,9 do if i==PLACE then ids[i]=0 else ids[i]=nxt nxt=nxt+1 end end
    for i=0,9 do w(0x1F12+i,ids[i]) end
    for i=0,19 do w(0x1F26+2*i,(i<10 and 0 or 0)) end
    for i=0,9 do local t=6000+i*20; w(0x1F26+2*ids[i],t&255); w(0x1F27+2*ids[i],t>>8) end
    w(0x1EB0,10); w(0x1EB1,0)
    w(0x1F00,PLACE&255); w(0x1F01,0); w(0x1F02,1); w(0x1F03,0)
    if PTS then local i=0 for v in PTS:gmatch("%d+") do w(0x1F4E+i,tonumber(v)); i=i+1 end end
    local s=emu.getState(); s["cpu.k"]=0; s["cpu.pc"]=0x8834; s["cpu.d"]=0; s["cpu.ps"]=s["cpu.ps"]&0xC7; s["cpu.dbr"]=0; s["cpu.sp"]=0x1FE; emu.setState(s)
    print("forced at f="..f)
  
  forced=true
end
emu.addMemoryCallback(function() if f>=FORCE and not forced then force() end end, emu.callbackType.exec, 0x00877D, 0x00877D)
local marks={[0x0F83D7]="results_flow",[0x0F8442]="draw_points",[0x0F84A4]="qualify_check",[0x0F84AC]="advance_track",
 [0x0F84CB]="FAIL_RACE",[0x0F84E1]="FAIL_COUNTRY",[0x0F84C0]="WIN_COUNTRY",[0x0F8584]="msg0",[0x0F8592]="msg1",[0x0F8597]="msg2",[0x0F85F2]="pw",
 [0x0F866F]="set_flag",[0x0F815A]="location_screen",[0x0F8C95]="title_screen",[0x0F818E]="main_menu_setup",[0x0F8F74]="to_main_menu",[0x0F818E]="loc818E"}
for a,n in pairs(marks) do
  emu.addMemoryCallback(function() print(string.format("f=%d %s PC=%06X A=%04X C=%d 1F06=%02X 1FF6=%04X",f,n,a,emu.getState()["cpu.a"],emu.getState()["cpu.ps"]&1,r(0x1F06),rw(0x1FF6))) end, emu.callbackType.exec, a, a)
end
emu.addEventCallback(function()
  f=f+1
  if forced and (f-FORCE)%30==0 then shot(string.format("%s_%04d",TAG,f-FORCE)) end
  if f==MAXF-1 or (forced and (f-FORCE)%400==0) then print(string.format("STATE f=%d 1F06=%02X 1F08=%02X unlock=%02X %02X %02X %02X %02X %02X 1F10=%02X 1F00=%02X 1F02=%02X",f,r(0x1F06),r(0x1F08),r(0x1F0A),r(0x1F0B),r(0x1F0C),r(0x1F0D),r(0x1F0E),r(0x1F0F),r(0x1F10),r(0x1F00),r(0x1F02))) end
  if f>=MAXF then emu.stop(0) end
end, emu.eventType.endFrame)
