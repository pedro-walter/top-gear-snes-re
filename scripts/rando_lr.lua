-- Left/Right on the SEED row: many rolls, held for different lengths; reports PC/seed
local ROOT=os.getenv("TG_ROOT") local wr=emu.memType.snesWorkRam
local sched={} local function press(f,b,n) for i=0,(n or 5) do sched[f+i]=b end end
local f=1300
press(f,"start") f=f+120 press(f,"start") f=f+180
press(f,"down") f=f+30 press(f,"down") f=f+30 press(f,"down") f=f+30   -- SEED row = 3
local N=tonumber(os.getenv("N") or 30)
for i=1,N do press(f,(i%2==0) and "left" or "right",(i%5)*4+2) f=f+40 end
LAST=f
local FR=0
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  FR=FR+1
  if FR%100==0 and FR>1500 then local s=emu.getState() print(FR,string.format("PC=%X seed=%04X%04X",s["cpu.pc"] or 0,r2(0x1F802),r2(0x1F800))) end
  if FR==LAST+60 then local fh=io.open(ROOT.."/out/lr_end.png","wb") fh:write(emu.takeScreenshot()) fh:close() emu.stop(0) end
end, emu.eventType.endFrame)
