-- Steering ramp lab: straight flat track, speed pinned, hold Left/Right from centre, log steering state per physics tick.
-- CAR=0..3. Output out/car_steer_<CAR>.csv : trial,spd,dir,tick,delta,state_before,X_at_9DDF
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local CAR=tonumber(os.getenv("CAR") or 0)
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local fh=io.open(os.getenv("TG_ROOT").."/out/car_steer_"..CAR..".csv","w")
fh:write("trial,spd,dir,k,delta,state,lat,lim,xreg\n")
local trials={}
for _,spd in ipairs{300,2000,5000,8000} do for _,d in ipairs{"right","left"} do for _,m in ipairs{"coast","gas"} do trials[#trials+1]={spd=spd,dir=d,m=m} end end end
local T=36
local F0=3200
local xreg=-1
emu.addMemoryCallback(function() xreg=emu.getState()["cpu.x"] end, emu.callbackType.exec, 0x05D8B7, 0x05D8B7)
emu.addMemoryCallback(function() xreg=emu.getState()["cpu.x"] end, emu.callbackType.exec, 0x05D8F1, 0x05D8F1)
R.steer=function(f)
  local i=(f-F0)//T+1; local tr=trials[i]
  local p={}
  if not tr or f<F0 then return p end
  p[tr.dir]=true
  if tr.m=="gas" then p.x=true end
  return p
end
local cur,lastk=nil,-1
emu.addMemoryCallback(function()   -- start of the steering block of a physics tick
  if R.f<F0 then return end
  local i=(R.f-F0)//T+1; local tr=trials[i]; if not tr then return end
  local k=(R.f-F0)%T
  xreg=-1
  cur={i=i,tr=tr,k=k,d=rw(0x1E90),st=rw(0x1E7E)}
end, emu.callbackType.exec, 0x05D86E, 0x05D86E)
R.run(F0+T*#trials,function(f)
  if f>=2990 then
    ww(0x1F8F,CAR) ww(0x1EE8,CAR*16)
    if f==3100 then for a=0x7E4000,0x7E7FFF do emu.write(a,0,mt) end end
    ww(0x1ED6,0) ww(0x1ED7,4000) ww(0x1E62,0xA7FF)
    for j=0,19 do local b=0x212+18*j
      if (b-0x212)~=rw(0x204) and (b-0x212)~=rw(0x206) then ww(b+2,0x6000) end end
  end
  if f<F0 then return end
  local i=(f-F0)//T+1; local tr=trials[i]; if not tr then return end
  local k=(f-F0)%T
  if k==0 then ww(0x1E8A,0) ww(0x1E7E,0) ww(0x1E82,0) ww(0x1EEC,0) end
  ww(0x1E5A,tr.spd)
  if cur and cur.i==i then
    local lat=rw(0x1E8A) if lat>=0x8000 then lat=lat-0x10000 end
    fh:write(string.format("%d,%d,%s%s,%d,%d,%d,%d,%d,%d\n",i,tr.spd,tr.dir,tr.m=="gas" and "+gas" or "",cur.k,cur.d,cur.st,lat,rw(0x1E94),xreg))
    cur=nil
  end
  ww(0x1E8A,0)
end,function() fh:close() end)
