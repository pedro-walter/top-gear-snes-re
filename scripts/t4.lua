print("io", io ~= nil, os ~= nil)
local f=0
emu.addEventCallback(function()
  f=f+1
  if f==3 then
    local png=emu.takeScreenshot()
    print(type(png), png and #png)
    local fh,err=io.open("out/x.png","wb")
    print(tostring(fh),err)
    if fh then fh:write(png) fh:close() end
    emu.stop(0)
  end
end, emu.eventType.endFrame)
