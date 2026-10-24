-- shared helpers: menu navigation to a 1-player race, frame counter, input
R = { f=0, hold={} }
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
if (os.getenv("TG_ROM") or ""):find("rando") then   -- the randomizer menu has six rows: PLAY GAME is the 6th
  ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1680,"down"},{1700,"a"} }
end
R.steer=nil   -- function(f) -> table of buttons during race
function R.run(maxf, onframe, finish)
  emu.addEventCallback(function()
    local p={}
    for _,e in ipairs(ev) do if R.f>=e[1] and R.f<e[1]+6 then p[e[2]]=true end end
    if R.steer and R.f>=3000 then for k,v in pairs(R.steer(R.f)) do p[k]=v end end
    emu.setInput(p,0)
  end, emu.eventType.inputPolled)
  emu.addEventCallback(function()
    R.f=R.f+1
    if onframe then onframe(R.f) end
    if R.f>=maxf then if finish then finish() end emu.stop(0) end
  end, emu.eventType.endFrame)
end
function R.rd(a) return emu.read(a, emu.memType.snesMemory) end
function R.rw(a) return emu.read(a, emu.memType.snesMemory) | (emu.read(a+1, emu.memType.snesMemory)<<8) end
function R.pc() local s=emu.getState() return (s["cpu.k"]<<16)|s["cpu.pc"] end
