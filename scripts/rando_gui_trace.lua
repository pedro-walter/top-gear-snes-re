local FR=0
local sched={} local function press(f,b,n) for i=0,n do sched[f+i]=b end end
press(1300,"start",5) press(1420,"start",5) press(1700,"down",5) press(1740,"down",5) press(1800,"right",5) press(1850,"right",5)
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  FR=FR+1
  if FR%50==0 and FR<2600 then local s=emu.getState() print("TR",FR,string.format("%02X:%04X",s["cpu.k"],s["cpu.pc"])) end
  if FR>=2600 then emu.stop(0) end
end, emu.eventType.endFrame)
