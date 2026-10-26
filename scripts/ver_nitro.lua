-- Length of one nitro (A pressed at frame 3300 of a race): frames and 1/60 s game time units ($1EAE). docs/15
-- TG_ROM="Top Gear (Europe).sfc" tools/mesen.sh scripts/ver_nitro.lua
local f=0
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"},{1900,"a"},{2100,"a"},{2300,"a"},{2500,"a"} }
local function rw(a) return emu.read(a,emu.memType.snesMemory)|(emu.read(a+1,emu.memType.snesMemory)<<8) end
local on=nil local t0,u0
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=2900 then p.x=true end
  if f>=3300 and f<3306 then p.a=true end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  local n=rw(0x1E6C)
  local act=(n&0x8000)~=0 and f>3290
  if act and not on then t0=f u0=rw(0x1EAE) print("nitro on at frame",f,"timeunits",u0) end
  if on and not act then print(string.format("nitro off at frame %d: %d frames, %d time units (1/60 s)",f,f-t0,rw(0x1EAE)-u0)) emu.stop(0) end
  on=act
  if f>5000 then print("no nitro") emu.stop(0) end
end, emu.eventType.endFrame)
