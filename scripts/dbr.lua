local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local done={}
local function probe(name,table_off)
  return function(addr,val)
    if done[name] then return end
    done[name]=true
    local s=emu.getState()
    print(string.format("%s pc=%06X dbr=%02X",name,addr,s["cpu.dbr"]))
  end
end
emu.addMemoryCallback(probe("car_stats 00:C6A1"), emu.callbackType.exec, 0x00C6A1, 0x00C6A1)
emu.addMemoryCallback(probe("topspd 05:D3EF"), emu.callbackType.exec, 0x05D3EF, 0x05D3EF)
emu.addMemoryCallback(probe("accel 05:D41D"), emu.callbackType.exec, 0x05D41D, 0x05D41D)
emu.addMemoryCallback(probe("shift 05:D39C"), emu.callbackType.exec, 0x05D39C, 0x05D39C)
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=3000 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function() f=f+1 if f>=3300 then emu.stop(0) end end, emu.eventType.endFrame)
