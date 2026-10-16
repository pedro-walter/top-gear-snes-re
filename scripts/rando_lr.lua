local ROOT=os.getenv("TG_ROOT") local wr=emu.memType.snesWorkRam
local sched={} local function press(f,b) for i=0,5 do sched[f+i]=b end end
local f=1300
press(f,"start") f=f+120 press(f,"start") f=f+180
local function key(b) press(f,b) f=f+30 end
key("down") key("down") key("right") key("right") key("right")
local FR=0
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  FR=FR+1
  if FR==1550 or FR==1900 or FR==2000 or FR==2100 then print(FR,string.format("seed=%04X%04X",r2(0x1F802),r2(0x1F800))) local fh=io.open(ROOT.."/out/lr_"..FR..".png","wb") fh:write(emu.takeScreenshot()) fh:close() end
  if FR>=2110 then emu.stop(0) end
end, emu.eventType.endFrame)
