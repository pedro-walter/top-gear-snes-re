dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local OUT=os.getenv("OUT")
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
R.steer=function(f) return {x=true} end
R.run(3110,function(f)
  if os.getenv("TRACK") and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv("TRACK")),mt) end
  if not os.getenv("TRACK") and f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==3100 then
    local fh=io.open(OUT..".vram","wb") for a=0,0xFFFF do fh:write(string.char(emu.read(a,emu.memType.snesVideoRam))) end fh:close()
    local fh=io.open(OUT..".oam","wb") for a=0,543 do fh:write(string.char(emu.read(a,emu.memType.snesSpriteRam))) end fh:close()
    local fh=io.open(OUT..".cg","wb") for a=0,511 do fh:write(string.char(emu.read(a,emu.memType.snesCgRam))) end fh:close()
  end
end)
