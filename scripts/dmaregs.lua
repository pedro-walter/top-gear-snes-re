dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local out=io.open("./out/dmaregs.txt","w")
R.steer=function(f) return {} end
emu.addEventCallback(function()
  if R.f>=2355 and R.f<=2362 then
    out:write("f="..R.f.."\n")
    for ch=0,7 do local b=0x4300+ch*16
      out:write(string.format("  ch%d ctrl=%02X dst=%02X src=%02X:%02X%02X len=%02X%02X\n",ch,emu.read(b,mt),emu.read(b+1,mt),emu.read(b+4,mt),emu.read(b+3,mt),emu.read(b+2,mt),emu.read(b+6,mt),emu.read(b+5,mt))) end
  end
end, emu.eventType.endFrame)
R.run(2365,nil,function() out:close() end)
