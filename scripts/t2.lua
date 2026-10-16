local f=0
local nexec=0
emu.addMemoryCallback(function(a,v) nexec=nexec+1 end, emu.callbackType.exec, 0x008000, 0x00FFFF)
emu.addEventCallback(function()
  f=f+1
  if f==600 then
    local s=emu.getState()
    local keys={} for k,_ in pairs(s) do keys[#keys+1]=k end table.sort(keys)
    print("nkeys",#keys)
    for i=1,math.min(#keys,60) do print(keys[i],s[keys[i]]) end
    print("exec cb",nexec)
    print("wram 7e0000", emu.read(0x7e0000, emu.memType.snesMemory), "type names:")
    for k,v in pairs(emu.memType) do io.write(k," ") end print()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
