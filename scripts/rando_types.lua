-- Object type catalogue: for every type in TYPES place 8 objects (alternating sides) at piece 3+3j and screenshot when the player approaches.
-- env: SEED, TYPES (comma list), LAT, TAG
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "16",16)
local TYPES={} for t in (os.getenv("TYPES") or "5"):gmatch("%d+") do TYPES[#TYPES+1]=tonumber(t) end
local LAT=tonumber(os.getenv("LAT") or 124)
local TAG=os.getenv("TAG") or "ty"
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local shot={}
R.run(3150+(3*#TYPES+4)*140,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==3140 then
    for i=0,(rw(0x200)//32)+40 do w2(0x6400+2*i,0) end
    for j=1,#TYPES do
      local base=(3*j)*32
      for k=0,7 do w2(0x6400+2*(base+k*2),(TYPES[j]<<9)|((k%2)<<8)|LAT) end
    end
  end
  if f>3150 then
    local pos=rw(0x1ED7)
    for j=1,#TYPES do
      if not shot[j] and pos>=3*j*1024-90 and pos<3*j*1024+2000 then
        shot[j]=true
        local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/%s_%02d.png",TAG,TYPES[j]),"wb") fh:write(emu.takeScreenshot()) fh:close()
      end
    end
  end
end)
