dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
R.steer=function(f) return {x=true} end
R.run(3300,function(f)
  if os.getenv("TRACK") and f>=2000 and f<2400 then emu.write(0x1F06,tonumber(os.getenv("TRACK")),mt) end
  if not os.getenv("TRACK") and f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>=2900 and f%10==0 then
    local L=rw(0x200)//32
    local g={} for i=0,L+63 do local w=emu.read(0x6400+2*i,wr)|(emu.read(0x6401+2*i,wr)<<8) if w>=0x8000 then g[#g+1]=string.format("%d:%04X",i,w) end end
    print("F",f,"L",L,"pos",rw(0x1ED7),table.concat(g," "))
  end
end)
