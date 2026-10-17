-- Logs every write to the RNG seed $1FF4/$1FF5 (frame, PC, value) through the menu walk and the race start. Original ROM.
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local out=io.open(os.getenv("TG_ROOT").."/out/rng_watch.txt","w")
emu.addMemoryCallback(function(a,v) out:write(R.f," pc=",string.format("%06X",R.pc())," val=",string.format("%02X",v)," addr=",string.format("%04X",a),"\n") end, emu.callbackType.write, 0x1FF4, 0x1FF5)
R.steer=function(f) return {x=true} end
R.run(3400,nil,function() out:close() end)
