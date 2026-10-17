-- screenshot at given slots: env SEED (hex), SLOTS (comma list), TAG; steers the autopilot like rando_types
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "1",16)
local S={} for t in (os.getenv("SLOTS") or "300"):gmatch("%d+") do S[#S+1]=tonumber(t) end
local TAG=os.getenv("TAG") or "sa"
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local shot={}
R.run(9000,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>3150 then
    local pos=rw(0x1ED7)
    for j=1,#S do
      if not shot[j] and pos>=S[j]*32 and pos<S[j]*32+2000 then
        shot[j]=true
        local fh=io.open(string.format("%s/out/%s_%d.png",os.getenv("TG_ROOT"),TAG,S[j]),"wb") fh:write(emu.takeScreenshot()) fh:close()
      end
    end
  end
end)
