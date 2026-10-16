dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local fh=io.open(os.getenv("TG_ROOT").."/out/ai_"..(os.getenv("TAG") or "a")..".csv","w")
local STEP=tonumber(os.getenv("STEP") or 10)
local function rb(a) return emu.read(a,emu.memType.snesMemory) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f) local ph=(f//50)%2 local t={x=true} if ph==0 then t.left=true else t.right=true end if os.getenv("NOSTEER") then t={x=true} end return t end
fh:write("f,spd,pos,lat,fuel,gear,nitro,pit,rank,cspd,cpos,clat,cfuel,cgear,cnitro,cpit,crank,top2,flag,lap\n")
R.run(tonumber(os.getenv("MAXF") or 9000),function(f)
  if f>=2940 and f%STEP==0 then
    fh:write(table.concat({f,sw(rw(0x1E5A)),rw(0x1ED7),sw(rw(0x1E8A)),rw(0x1E62),rw(0x1E72),rw(0x1E6C),rw(0x1E86),rw(0x1E7A),
      sw(rw(0x1E5C)),rw(0x1EDA),sw(rw(0x1E8C)),rw(0x1E64),rw(0x1E74),rw(0x1E6E),rw(0x1E88),rw(0x1E7C),rw(0x1EE2),rw(0x1EF6),rb(0x1E56)},","),"\n")
  end
end,function() fh:close() end)
