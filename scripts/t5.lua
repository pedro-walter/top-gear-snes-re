local f=0
emu.addEventCallback(function()
  local ok,err=pcall(emu.setInput,{start=true},0,0)
  if f%100==0 then print("set",f,ok,err, emu.getInput(0,0).start) end
end, emu.eventType.inputPolled)
emu.addEventCallback(function() f=f+1 if f>400 then emu.stop(0) end end, emu.eventType.endFrame)
