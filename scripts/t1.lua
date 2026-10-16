print("start")
local f=0
emu.addEventCallback(function()
  f=f+1
  if f==60 then print("f60") emu.stop(0) end
end, emu.eventType.endFrame)
