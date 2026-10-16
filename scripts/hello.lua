local f=0
emu.addEventCallback(function()
  f=f+1
  if f==300 then
    local s=emu.getState()
    local out=io.open("/tmp/claude-1000/-home-pedro-development-snes-rea/fa923adb-1b24-4f70-8956-215f83d5cc12/scratchpad/hello.txt","w")
    if out then out:write("frame "..f.." pc="..string.format("%X",s["cpu.pc"]).." k="..s["cpu.k"].."\n") out:close() else print("noio") end
    print("hello frame "..f)
    emu.stop(0)
  end
end, emu.eventType.endFrame)
