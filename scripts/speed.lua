local OUT="./out/"
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local fh=io.open(OUT.."speed_samples.bin","wb")
local shots={[3186]=1,[3366]=1,[3594]=1,[3900]=1}
local SZ=0x8000
local function snap()
  local t={}
  for i=0,SZ-1 do t[#t+1]=string.char(emu.read(i, emu.memType.snesWorkRam)) end
  fh:write(table.concat(t))
end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=3000 and f<3600 then
    p.x=true
    local ph=(f//45)%2
    if ph==0 then p.left=true else p.right=true end   -- weave to stay near the road
  end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if shots[f] then local g=io.open(OUT.."sp_"..f..".png","wb") g:write(emu.takeScreenshot()) g:close() end
  if f>=3000 and f<4200 and f%6==0 then snap() end
  if f>=4200 then fh:close() emu.stop(0) end
end, emu.eventType.endFrame)
