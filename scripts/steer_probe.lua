dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f)
  local t={x=true}
  if f>3400 and f<3440 then t.right=true end
  if f>3520 and f<3560 then t.left=true end
  return t end
R.run(3700,function(f)
  if f>=2000 and f<2400 then ww(0x1F06,8) end
  if f>=2990 then ww(0x1F8F,2) ww(0x1EE8,32) end
  if f>=3380 and f%5==0 then print(f,"lat",sw(rw(0x1E8A)),"steer",sw(rw(0x1E7E)),"pos",rw(0x1ED7),"spd",rw(0x1E5A)) end
end)
