local ROOT=os.getenv("TG_ROOT") local wr=emu.memType.snesWorkRam
local rs=tonumber(os.getenv("RS") or 1) math.randomseed(rs)
local sched={} local function press(f,b,n) for i=0,n do sched[f+i]=b end end
local f=1300
press(f,"start",5) f=f+120 press(f,"start",5) f=f+math.random(1,200)
press(f,"down",5) f=f+math.random(5,40) press(f,"down",5) f=f+math.random(5,40) press(f,"down",5) f=f+math.random(1,60)
for i=1,60 do press(f,math.random()<0.5 and "left" or "right",math.random(0,14)) f=f+math.random(1,40) end
LAST=f
local FR=0
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
local seen={}
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  FR=FR+1
  if FR>LAST then local s=emu.getState() local k=string.format("%X",s["cpu.pc"]) seen[k]=(seen[k] or 0)+1 end
  if FR==LAST+300 then local n=0 local ks="" for k,v in pairs(seen) do n=n+1 ks=ks.." "..k end print("FUZZ",rs,"distinct pcs",n,ks,string.format("seed=%04X%04X",r2(0x1F802),r2(0x1F800))) emu.stop(0) end
end, emu.eventType.endFrame)
