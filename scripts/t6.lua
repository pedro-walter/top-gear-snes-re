dofile(os.getenv("TG_ROOT").."/scripts/overlay.lua")
local f=0
emu.addEventCallback(function() f=f+1 if f==200 then print("overlay ok") emu.stop(0) end end, emu.eventType.endFrame)
