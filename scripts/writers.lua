-- who writes WRAM $1E58-$1E5F ?
local OUT="./out/"
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
local seen={}
local function cb(addr,val)
  if f<1500 then return end
  local s=emu.getState()
  local pc=(s["cpu.k"]<<16)|s["cpu.pc"]
  local key=string.format("%06X>%06X",pc,addr)
  local e=seen[key]
  if not e then e={n=0,first=val,last=val} seen[key]=e end
  e.n=e.n+1 e.last=val
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x7E1EF0, 0x7E1F00)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x001EF0, 0x001F00)
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=3000 and f<3500 then p.x=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if f>=3000 then
    for k,e in pairs(seen) do print("W",k,e.n,e.first,e.last) end
    emu.stop(0)
  end
end, emu.eventType.endFrame)
