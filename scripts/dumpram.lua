local OUT=os.getenv("TG_ROOT").."/out/"
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local dumps={[1200]=true,[2300]=true,[3300]=true,[6000]=true,[12000]=true}
local function dump(tag)
  local t={}
  for i=0,0x1FFFF do t[#t+1]=string.char(emu.read(i, emu.memType.snesWorkRam)) end
  local fh=io.open(OUT.."wram_"..tag..".bin","wb") fh:write(table.concat(t)) fh:close()
end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2650 then
    p.x=true
    local ph=(f//90)%4
    if ph==1 then p.left=true elseif ph==3 then p.right=true end
    if f%700<10 then p.a=true end
  end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if dumps[f] then dump(tostring(f)) end
  if f>=12000 then emu.stop(0) end
end, emu.eventType.endFrame)
