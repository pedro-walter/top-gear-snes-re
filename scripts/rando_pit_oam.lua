dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local TARGET=tonumber(os.getenv("TARGET") or "-17500")
R.steer=function(f)
  local prog=rw(0x1ED7) local pit=rw(0x1EF0) local lat=sw(rw(0x1E8A)) local t={x=true}
  local d=(prog-(pit-1500))%rw(0x200)
  if d<3600 then if lat<TARGET-300 then t.right=true elseif lat>TARGET+300 then t.left=true end
  else if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end end
  return t
end
local dumped={}
R.run(4700,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F806,0xA55A) end
  if f>=4020 and f%60==0 then
    local o={} for a=0,543 do o[a]=emu.read(a,emu.memType.snesSpriteRam) end
    local L={}
    for i=0,127 do local y=o[4*i+1] if y<224 then local h=(o[512+i//4]>>(2*(i%4)))&3 L[#L+1]=string.format("%d(%d,%d t%02X a%02X h%d)",i,o[4*i]+((h&1)*256),y,o[4*i+2],o[4*i+3],h) end end
    print("F",f,"st",string.format("%04X",rw(0x1E86)),#L,table.concat(L," "):sub(1,500))
  end
end)
