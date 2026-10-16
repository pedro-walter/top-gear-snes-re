dofile("./scripts/common.lua")
local mt=emu.memType.snesMemory
local TRACK=tonumber(os.getenv("TRACK") or 16)
local DIFF=tonumber(os.getenv("DIFF") or 0)
R.steer=function(f) return {} end
R.run(3300,function(f)
  if f>=2000 and f<2400 then
    emu.write(0x1F06,TRACK,mt)
  end
  if f==3250 then
    local fh=io.open("./out/trk_"..TRACK..".bin","wb")
    for a=0x7E4000,0x7E71FF do fh:write(string.char(emu.read(a,mt))) end
    -- also trackno, laps, difficulty, length, pit start, graphics-related
    for _,a in ipairs({0x1F06,0x1F10,0x0200,0x1EF0,0x1E56}) do local v=emu.read(a,mt)|(emu.read(a+1,mt)<<8); print(string.format("RES %d %04X=%d",TRACK,a,v)) end
    fh:close()
  end
end)
