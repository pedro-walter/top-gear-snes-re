-- no input: title -> attract/demo race.  Logs and screenshots.
local ROOT=os.getenv("TG_ROOT") local mt=emu.memType.snesMemory
local f=0
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
emu.addEventCallback(function()
  f=f+1
  if f%300==0 then local s=emu.getState() print(string.format("%d pc=%02X:%04X attract=%04X track=%d len=%d laps=%d",f,s["cpu.k"],s["cpu.pc"],rw(0x1FF6),emu.read(0x1F06,mt),rw(0x200),rw(0x1E56))) end
  if f%900==0 then local fh=io.open(ROOT.."/out/idle_"..f..".png","wb") fh:write(emu.takeScreenshot()) fh:close() end
  if f>=tonumber(os.getenv("MAXF") or 9000) then emu.stop(0) end
end, emu.eventType.endFrame)
