-- Track series test on the randomizer ROM (build with tools/build_rando.py).  Boots, sets the TRACKS row (n = TRACKS: 0 = infinity, 1 = single race,
-- 2.. = presses of Right from "1 TRACK"), optionally 2 players, starts the game and forces the end of every race (forged finish list, like
-- scripts/race_end_force.lua), then follows results -> ranking -> next race ... -> podium -> main menu.  Screenshots of the post-race screens.
-- env: SHOTS (comma list of frames), TRACKS (default 2), TWO=1, PLACES="0,3,5" (0-based race place of the human per race), MAXF, TAG, SHOT_EVERY (frames, default 45), SEEDROW=1 to open the seed row
local ROOT=os.getenv("TG_ROOT")
dofile(ROOT.."/out/rando.lua")
local E=function(k,d) return tonumber(os.getenv(k) or d) end
local TR=E("TRACKS",2)
local MAXF=E("MAXF",9000)
local TAG=os.getenv("TAG") or "ser"
local EVERY=E("SHOT_EVERY",45)
local PLACES={} for v in (os.getenv("PLACES") or "0,1,2,3,4,5,6,7"):gmatch("%d+") do PLACES[#PLACES+1]=tonumber(v) end
local mt=emu.memType.snesMemory
local function w(a,v) emu.write(a,v,mt) end
local function r(a) return emu.read(a,mt) end
local function rw(a) return r(a)|(r(a+1)<<8) end
local sched={} local function press(f,b) for i=0,5 do sched[f+i]=b end end
press(1300,"start") press(1420,"start")
local f0=1700
local function key(b) press(f0,b) f0=f0+30 end
if os.getenv("TWO") then key("right") end
key("down") key("down")                       -- TRACKS row
if TR==0 then key("left") else for i=2,TR do key("right") end end
key("down") key("down") key("down")           -- PLAY GAME
key("a")
local f=0 local races=0 local inflow=false local lastflow=0 local pokeA=false local ended=false
local function shot(n) local fh=io.open(ROOT.."/out/"..n..".png","wb") if fh then fh:write(emu.takeScreenshot()) fh:close() end end
emu.addEventCallback(function()
  local p={}
  local b=sched[f] if b then p[b]=true end
  if pokeA and (f%90)<6 then p.a=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
local function force()
  races=races+1
  local PLACE=PLACES[(races-1)%#PLACES+1]
  local ids={} local nxt=2
  for i=0,9 do if i==PLACE then ids[i]=0 else ids[i]=nxt nxt=nxt+1 end end
  if os.getenv("TWO") and PLACE~=0 then   -- player 2 right behind
    for i=0,9 do if ids[i]==2 then ids[i]=1 break end end
  end
  for i=0,9 do w(0x1F12+i,ids[i]) end
  for i=0,9 do local t=6000+i*20; w(0x1F26+2*ids[i],t&255); w(0x1F27+2*ids[i],t>>8) end
  if os.getenv("HIGH") then   -- forged big scores (car id: value) to check the 5 digit ranking
    for id,v in pairs({[0]=65000,[2]=12345,[3]=999,[4]=5,[5]=10000}) do
      emu.write(0x1FA20+id,v&255,emu.memType.snesWorkRam) emu.write(0x1FA40+id,v>>8,emu.memType.snesWorkRam) end
  end
  w(0x1EB0,10); w(0x1EB1,0)
  w(0x1F00,PLACE&255); w(0x1F01,0); w(0x1F02,1); w(0x1F03,0)
  local s=emu.getState(); s["cpu.k"]=0; s["cpu.pc"]=0x8834; s["cpu.d"]=0; s["cpu.ps"]=s["cpu.ps"]&0xC7; s["cpu.dbr"]=0; s["cpu.sp"]=0x1FE; emu.setState(s)
  print(string.format("f=%d race %d forced (place %d) seed=%04X%04X track=%d",f,races,PLACE,rw(0x7FF802-0x7E0000+0x1F800-0x1F800) ,0,r(0x1F06)))
end
emu.addMemoryCallback(function()
  if not inflow and f>2500 and f-lastflow>500 and not ended then inflow=true force() pokeA=true end
end, emu.callbackType.exec, 0x00877D, 0x00877D)
emu.addMemoryCallback(function() inflow=false lastflow=f print("f="..f.." back in race setup (main_restart)") end, emu.callbackType.exec, 0x008875, 0x008875)
local marks={results_flow=0x0F83D7,podium_start=SYM.podium_start,hook_podend=SYM.hook_podend,har_next=SYM.har_next,hook_play=SYM.hook_play,mm_run=SYM.mm_run}
for n,a in pairs(marks) do
  emu.addMemoryCallback(function()
    print(string.format("f=%d %s",f,n))
    if n=="hook_podend" then ended=true pokeA=false end
  end, emu.callbackType.exec, a, a)
end
local SH={} for v in (os.getenv('SHOTS') or ''):gmatch('%d+') do SH[tonumber(v)]=true end
emu.addEventCallback(function()
  f=f+1
  if SH[f] then shot(string.format('%s_s%05d',TAG,f)) end
  if inflow and f%EVERY==0 then shot(string.format("%s_%05d",TAG,f)) end
  if (ended or not inflow) and f%300==0 then shot(string.format("%s_%05d",TAG,f)) end
  if f>=MAXF then
    print(string.format("END f=%d races=%d DONE=%d TRKS=%d", f, races, emu.read(0xFA02,emu.memType.snesWorkRam+0) , 0))
    emu.stop(0) end
end, emu.eventType.endFrame)
