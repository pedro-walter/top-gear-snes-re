dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f) return {x=true} end
R.run(3700,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,0x16) w2(0x1F802,0) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f%100==0 and f>=2900 then print("POS",f,rw(0x1ED7),rw(0x1ED5),rw(0x1ED9),rw(0x1E5A),rw(0x200)) end
end)
