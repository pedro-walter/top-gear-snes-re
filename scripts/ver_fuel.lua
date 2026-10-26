-- Fuel burned per physics tick / per frame / per distance while accelerating (exec hook on 05:D638). docs/15
-- TG_ROM="Top Gear (Europe).sfc" tools/mesen.sh scripts/ver_fuel.lua
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"},{1900,"a"},{2100,"a"},{2300,"a"},{2500,"a"} }
local function rw(a) return emu.read(a,emu.memType.snesMemory)|(emu.read(a+1,emu.memType.snesMemory)<<8) end
local last=nil
local S={ticks=0,burn=0,dist=0,delta=0,frames0=nil,frames1=0,sp=0}
emu.addMemoryCallback(function()
  if f<3400 then return end
  local fuel=rw(0x1E62); local d=rw(0x1E90); local sp=rw(0x1E5A)
  if last and last.fuel>=fuel and last.fuel-fuel<200 and last.f==f-0 or (last and last.fuel>=fuel and last.fuel-fuel<200) then
    -- burn of previous tick, previous tick's delta/speed
    S.ticks=S.ticks+1; S.burn=S.burn+(last.fuel-fuel); S.dist=S.dist+last.sp*last.d; S.delta=S.delta+last.d; S.sp=S.sp+last.sp
    if not S.f0 then S.f0=f end
    S.f1=f
  end
  last={fuel=fuel,d=d,sp=sp}
end, emu.callbackType.exec, 0x05D638, 0x05D638)
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2900 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if f>=7000 then
    local fr=(S.f1 or 0)-(S.f0 or 0)
    print(string.format("ticks=%d frames=%d burn=%d dist=%d sumdelta=%d  burn/tick=%.2f  frames/tick=%.3f delta/tick=%.3f  burn/dist*1e3=%.4f burn/frame=%.3f burn/timeunit=%.3f",S.ticks,fr,S.burn,S.dist,S.delta,S.burn/S.ticks,fr/S.ticks,S.delta/S.ticks,S.burn/S.dist*1000,S.burn/fr,S.burn/S.delta))
    emu.stop(0)
  end
end, emu.eventType.endFrame)
