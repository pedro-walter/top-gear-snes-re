-- View object types: poke one object type per piece (alternating sides) over the whole object table, screenshot while driving.
-- env: SEED (hex), TYPES (comma list), LAT (lateral/128 byte, default 124), TAG
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local TYPES={} for t in (os.getenv("TYPES") or "5"):gmatch("%d+") do TYPES[#TYPES+1]=tonumber(t) end
local LAT=tonumber(os.getenv("LAT") or 124)
local TAG=os.getenv("TAG") or "sig"
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local k=0
R.run(3200+12*tonumber(os.getenv("STEPF") or 45)+10,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f==3150 then
    local n=rw(0x200)//32
    for i=64,n+60 do
      local piece=i//32
      local t=TYPES[(piece//1)%#TYPES+1]
      if i%4==2 then
        local side=((i//4)%2)
        w2(0x6400+2*i,(t<<9)|(side<<8)|LAT)
      else w2(0x6400+2*i,0) end
    end
  end
  if f>=3200 and (f-3200)%(tonumber(os.getenv("STEPF") or 45))==0 then
    k=k+1
    local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/%s_%02d.png",TAG,k),"wb") fh:write(emu.takeScreenshot()) fh:close()
  end
end)
