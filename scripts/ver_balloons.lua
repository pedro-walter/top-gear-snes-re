-- Force speech-balloon ids (TG_IDS="6 7 8 ...") in a race and screenshot them to $TG_OUT/idNN_25.png / _60.png.
-- Run once per ROM: TG_OUT=dir TG_ROM="Top Racer (Japan).sfc" tools/mesen.sh scripts/ver_balloons.lua  (docs/15)
local OUT=os.getenv("TG_OUT").."/"
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"},{1900,"a"},{2100,"a"},{2300,"a"},{2500,"a"} }
local ids={}
for s in (os.getenv("TG_IDS") or "15"):gmatch("%d+") do ids[#ids+1]=tonumber(s) end
local function shot(n) local fh=io.open(OUT..n..".png","wb") if fh then fh:write(emu.takeScreenshot()) fh:close() end end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2900 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  for i,id in ipairs(ids) do
    local t=3500+i*300
    if f==t then emu.write(0x0128,0,emu.memType.snesMemory); emu.write(0x0118,id,emu.memType.snesMemory); emu.write(0x0119,0,emu.memType.snesMemory) end
    if f==t+25 or f==t+60 then shot(string.format("id%02d_%d",id,f-t)) end
  end
  if f>=3500+(#ids+1)*300 then emu.stop(0) end
end, emu.eventType.endFrame)
