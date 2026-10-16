local f=0
emu.addEventCallback(function()
  f=f+1
  if f%120==0 then
    local png=emu.takeScreenshot()
    local fh=io.open("./out/shot_"..string.format("%04d",f)..".png","wb")
    if fh then fh:write(png) fh:close() end
  end
  if f>=720 then emu.stop(0) end
end, emu.eventType.endFrame)
