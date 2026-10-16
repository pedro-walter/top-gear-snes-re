dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 0)
local shots={}
for s in (os.getenv("SHOTS") or "2380,3400"):gmatch("%d+") do shots[tonumber(s)]=true end
R.steer=function(f) return {} end
R.run(tonumber(os.getenv("MAXF") or 3450),function(f)
  if f>=2000 and f<2400 then emu.write(0x1F06,TRACK,mt) end
  if shots[f] then
    local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/ts_%d_%d.png",TRACK,f),"wb")
    fh:write(emu.takeScreenshot()) fh:close()
  end
end)
