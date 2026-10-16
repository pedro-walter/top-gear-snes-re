-- Coverage trace: records first execution of every CPU address with M/X flags.
-- Output: out/trace_<tag>.txt   lines "BBAAAA m x" ; also RAM-code bytes in out/ramcode_<tag>.txt
local OUT=os.getenv("TG_ROOT").."/out/"
local TAG = "main"
local LAST = 12000
local f=0
local seen, order = {}, {}
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local function pad() return {} end

emu.addMemoryCallback(function(addr, val)
  if not seen[addr] then
    local s=emu.getState()
    local m,x
    if s["cpu.emulationMode"] then m,x=1,1 else
      m = (s["cpu.ps"] & 0x20)~=0 and 1 or 0
      x = (s["cpu.ps"] & 0x10)~=0 and 1 or 0
    end
    seen[addr]=true
    order[#order+1]=string.format("%06X %d %d",addr,m,x)
  end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)

emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2650 then
    p.x=true             -- accelerate
    local ph=(f//90)%4
    if ph==1 then p.left=true elseif ph==3 then p.right=true end
    if f%700<10 then p.a=true end   -- nitro?
  end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  f=f+1
  if f%1000==0 then print("frame",f,"addrs",#order) end
  if f==3300 or f==4500 or f==LAST then
    local fh=io.open(OUT.."race_"..f..".png","wb") if fh then fh:write(emu.takeScreenshot()) fh:close() end
  end
  if f>=LAST then
    local fh=io.open(OUT.."trace_"..TAG..".txt","w")
    for _,l in ipairs(order) do fh:write(l,"\n") end
    fh:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
