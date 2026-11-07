-- Fuel lab: drive N laps with a scripted driver (car centred on the road by poking the lateral position)
-- and log fuel/time per lap.  Env: TRACK CAR POLICY(see below) CAP NITRO MAXF TAG
-- POLICY: "opt" = shift at SH thresholds (km/h list "a,b,c,d"), throttle always; CAP = lift above km/h
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 8)
local CAR=tonumber(os.getenv("CAR") or 2)
local CAP=tonumber(os.getenv("CAP") or 999)
local NITRO=tonumber(os.getenv("NITRO") or 0)   -- frames after the green light at which nitro is fired (0 = never)
local MAXF=tonumber(os.getenv("MAXF") or 30000)
local TAG=os.getenv("TAG") or "x"
local STEER=tonumber(os.getenv("STEER") or 0)      -- 1 = steer with a PD controller instead of poking the lateral position
local CORNER=os.getenv("CORNER") or "full"        -- full | lift | brake  (what to do when speed*|c| is above the accelerating grip limit)
local CAPU=tonumber(os.getenv("CAPU") or 99999)   -- lift above this raw speed (units; km/h = units*24/1024)
local KP=tonumber(os.getenv("KP") or 25)
local DB=tonumber(os.getenv("DB") or 1200)
local PITAT=tonumber(os.getenv("PITAT") or 0)     -- pit trigger when track pos >= this on lap PITLAP (forces $1E86=FFFF like driving over the entrance)
local PITLAP=tonumber(os.getenv("PITLAP") or 0)
local PITHOLD=tonumber(os.getenv("PITHOLD") or 0)   -- 1 = release accelerate in the pit (full refuel), 0 = hold it (leave at once)
local COASTAT=tonumber(os.getenv("COASTAT") or 0)   -- frame after start at which the tank is set to 40 units (then it runs dry)
local COASTG=tonumber(os.getenv("COASTG") or 4)    -- gear (0..4) to coast in once the tank is empty
local coast0=nil
local pitted=false
local PITFUEL=tonumber(os.getenv("PITFUEL") or 0)
local lastlat=0
local hits=0
local SH={}
for v in (os.getenv("SH") or "40,63,100,167"):gmatch("[^,]+") do SH[#SH+1]=tonumber(v) end
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local fh=io.open(os.getenv("TG_ROOT").."/out/fuel/"..TAG..".csv","w")
fh:write("f,spd,gear,fuel,pos,laps,delta,flags,lat\n")
local started=nil
local ticks=0
emu.addMemoryCallback(function()
  if not started then return end
  ticks=ticks+1
  fh:write(table.concat({R.f-started,sw(rw(0x1E5A)),rw(0x1E72),rw(0x1E62),rw(0x1ED7),rw(0x1E76),rw(0x1E90),rw(0x1EF5),sw(rw(0x1E8A))},","),"\n")
end, emu.callbackType.exec, 0x05D2E0, 0x05D2E0)
local want={}
R.steer=function(f)
  local t={}
  local v=sw(rw(0x1E5A))*24//1024
  local pos=rw(0x1ED7)
  local c=emu.read(0x7E4C00+((pos>>4)&0xFFFE),mt); if c>=128 then c=c-256 end
  local over=(sw(rw(0x1E5A))*math.abs(c) > 196608)
  local g=rw(0x1E72)
  if COASTAT>0 and started and rw(0x1E62)==0 then
    t.x=nil
    if g>COASTG then t.l=(R.f%2==0) elseif g<COASTG then t.r=(R.f%2==0) end
  end
  if v<=CAP and sw(rw(0x1E5A))<CAPU then t.x=true end
  if rw(0x1E86)>=0x8000 and pitted then
    t.x=nil
    local st=0x10000-rw(0x1E86)
    if st>=3 and (rw(0x1E62)>=PITFUEL) then t.x=(R.f%4<2) end   -- fresh presses leave the pit
  end
  if started and STEER==1 then
    local lat=sw(rw(0x1E8A))
    local pred=lat+KP*(lat-lastlat)/3
    lastlat=lat
    if pred>DB then t.left=true elseif pred<-DB then t.right=true end
    if over and CORNER=="lift" then t.x=nil end
    if over and CORNER=="brake" then t.y=true end
  end
  if started then
    local need=g
    -- count how many shifts needed
    if g<4 and v>=SH[g+1] then t.r=(R.f%2==0) end
  end
  if NITRO>0 and started and R.f-started>=NITRO and R.f-started<NITRO+4 then t.a=true end
  return t
end
R.run(MAXF,function(f)
  if f>=2000 and f<2400 then ww(0x1F06,TRACK) end
  if f>=2990 then ww(0x1F8F,CAR) ww(0x1EE8,CAR*16) emu.write(0x1EFD,({100,64,90,82})[CAR+1],mt) ww(0x1F7A,0x0010) ww(0x1F7C,0x0020) end
  if f>=3000 then
    if not started and f>3050 and sw(rw(0x1E5A))>1500 and rw(0x1E76)~=0xFFFF+1 then started=f end
    if started and STEER==0 then ww(0x1E8A,0) end
  end
  if NITRO>0 and started and f>=started+NITRO-2 and f<started+NITRO+8 then print("nitro",f-started,string.format("%04X %04X",rw(0x1E6C),rw(0x1F7E))) end
  if f>=3000 and f%100==0 then print(f, rw(0x1E5A), rw(0x1E72), rw(0x1E62), rw(0x1ED7), rw(0x1E76), rw(0x1E56), rb(0x1EFD)) end
  if PITAT>0 and started and not pitted and rw(0x1E76)==PITLAP and rw(0x1ED7)>=PITAT then if rw(0x1E62)==0 then ww(0x1EB4,rw(0x1EB4)|1) end ww(0x1E86,0xFFFF) pitted=true print("PIT trigger",f-started,rw(0x1ED7),rw(0x1E62),"speed",rw(0x1E5A)) end
  if pitted and rw(0x1E86)~=0 and f%30==0 then print("pit",f-started,string.format("st=%04X",rw(0x1E86)),rw(0x1ED7),rw(0x1E5A),rw(0x1E62)) end
  if COASTAT>0 and started and f==started+COASTAT then ww(0x1E62,40) end
  if COASTAT>0 and started and rw(0x1E62)==0 and not coast0 then coast0={f=f,pos=rw(0x1ED7),lap=rw(0x1E76),v=rw(0x1E5A)} end
  if coast0 and (f-coast0.f)%120==0 then print("coast",f-coast0.f,rw(0x1ED7)-coast0.pos+ (rw(0x1E76)-coast0.lap)*40000, sw(rw(0x1E5A))*24//1024, rw(0x1E72)) end
  if coast0 and f-coast0.f>2400 then emu.stop(0) end
  if started and rw(0x1E76)<0x100 and rw(0x1E76)>=math.min(rw(0x1E56),tonumber(os.getenv("LAPS") or 99)) and rw(0x1E56)>0 then emu.stop(0) end
end,function() fh:close() print("ticks",ticks) end)
