local OUT=os.getenv("TG_ROOT").."/out/"
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local btns={"b","y","x","up","r","l"}
local function shot(n) local fh=io.open(OUT..n..".png","wb") if fh then fh:write(emu.takeScreenshot()) fh:close() end end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2700 then local k=((f-2700)//250)+1 if btns[k] then p[btns[k]]=true end end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if f>=2700 and (f-2700)%250==240 then shot("b"..((f-2700)//250+1)) end
  if f>=2700+250*6 then emu.stop(0) end
end, emu.eventType.endFrame)
