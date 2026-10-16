local t={} for k,_ in pairs(emu.memType) do t[#t+1]=k end table.sort(t) print(table.concat(t," "))
local f=0
emu.addEventCallback(function() f=f+1 if f==5 then emu.stop(0) end end, emu.eventType.endFrame)
