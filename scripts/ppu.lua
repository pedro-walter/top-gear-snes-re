local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2650 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if f==1200 or f==3300 then
    local s=emu.getState()
    local keys={} for k,_ in pairs(s) do if k:find("^ppu") or k:find("^dma") or k:find("hdma") then keys[#keys+1]=k end end
    table.sort(keys)
    print("=== frame",f)
    for _,k in ipairs(keys) do
      if k:find("bgMode") or k:find("^ppu.layers") or k:find("mode7") or k:find("hdmaEnabled") or k:find("hdmaChannels") or k:find("%.hdmaEnabled") or k:find("bgSize") or k:find("tilemap") or k:find("mainScreen") or k:find("subScreen") or k:find("colorMath") or k:find("hOffset") or k:find("vOffset") or k:find("chrAddr") or k:find("channel%[%d%]%.destAddress") or k:find("hdmaEnabled") or k:find("channel%[%d%]%.hdmaMode") or k:find("channel%[%d%]%.transferMode") or k:find("channel%[%d%]%.hdma") then print(k, s[k]) end
    end
  end
  if f>=3301 then emu.stop(0) end
end, emu.eventType.endFrame)
