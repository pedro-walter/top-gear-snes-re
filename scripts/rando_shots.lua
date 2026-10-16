-- Screenshots at given track positions (units) while the autopilot drives.  env: SEED (hex), POSL (comma list), TAG
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory local wr=emu.memType.snesWorkRam
local SEED=tonumber(os.getenv("SEED") or "12345678",16)
local POS={} for t in (os.getenv("POSL") or "1000"):gmatch("%d+") do POS[#POS+1]=tonumber(t) end
local TAG=os.getenv("TAG") or "shot"
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f)
  local lat=sw(rw(0x1E8A)) local t={x=true}
  if lat>1200 then t.left=true elseif lat<-1200 then t.right=true end
  return t
end
local done={}
R.run(3150+#POS*0+ (POS[#POS] or 1000)//6+600,function(f)
  if f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f>3150 then
    local pos=rw(0x1ED7)
    for j,p in ipairs(POS) do
      if not done[j] and pos>=p and pos<p+2000 then
        done[j]=true
        local fh=io.open(string.format(os.getenv("TG_ROOT").."/out/%s_%02d.png",TAG,j),"wb") fh:write(emu.takeScreenshot()) fh:close()
      end
    end
  end
end)
