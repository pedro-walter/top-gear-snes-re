local FR=0
local sched={} local function press(f,b,n) for i=0,n do sched[f+i]=b end end
press(1300,"start",5) press(1420,"start",5) press(1700,"down",5) press(1740,"down",5) press(1800,"right",5)
emu.addEventCallback(function() local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0) end, emu.eventType.inputPolled)
local ring={} local n=0 local done=false
local cb
for _,a in ipairs({0x0F918B,0x0F91A0,0x0F9242,0x10F3B6,0x10F3C9,0x10F388,0x10F3CF,0x0F9295,0x10F401}) do
  emu.addMemoryCallback(function(ad,v) local s=emu.getState() print("EV",FR,string.format("%06X S=%04X",ad,s["cpu.sp"])) end, emu.callbackType.exec, a, a)
end
local function ringcb(addr,val) if done then return end ring[n%600]=addr n=n+1 end
emu.addMemoryCallback(ringcb, emu.callbackType.exec, 0x0F8000, 0x10FFFF)
cb=emu.addMemoryCallback(function(addr,val)
  if done then return end
  if true then
    done=true
    local s=emu.getState()
    print("CRASH at",string.format("%06X S=%04X A=%04X X=%04X Y=%04X DBR=%02X D=%04X P=%02X",addr,s["cpu.sp"],s["cpu.a"],s["cpu.x"],s["cpu.y"],s["cpu.dbr"],s["cpu.d"],s["cpu.ps"]))
    local t={} for i=n-90,n-1 do if i>=0 then t[#t+1]=string.format("%06X",ring[i%600]) end end
    print("RING",table.concat(t," "))
    local sp=s["cpu.sp"] local st={} for i=1,24 do st[#st+1]=string.format("%02X",emu.read(sp+i,emu.memType.snesMemory)) end
    local rb={} for a=0x10F3B6,0x10F3E0 do rb[#rb+1]=string.format("%02X",emu.read(a,emu.memType.snesMemory)) end print("ROMBYTES",table.concat(rb," "))
    local sb={} for a=0x1E8,0x1FF do sb[#sb+1]=string.format("%02X",emu.read(a,emu.memType.snesMemory)) end print("STACKTOP",table.concat(sb," "))
    print("STACK",table.concat(st," "))
  end
end, emu.callbackType.exec, 0x002000, 0x0043FF)
emu.addEventCallback(function()
  FR=FR+1
  if FR>=2000 then emu.stop(0) end
end, emu.eventType.endFrame)
