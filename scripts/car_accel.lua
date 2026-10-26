-- Per-car acceleration test: flat straight track, full throttle, auto gearbox, no nitro, full tank.
-- CAR=0..3 (red,white,purple,blue). Logs speed/gear/top/delta per frame to out/car_accel_<CAR>.csv
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local CAR=tonumber(os.getenv("CAR") or 0)
local N=tonumber(os.getenv("N") or 5000)
local F0=3150
local mt=emu.memType.snesMemory
local function rb(a) return emu.read(a,mt) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function ww(a,v) emu.write(a,v&0xFF,mt) emu.write(a+1,(v>>8)&0xFF,mt) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local fh=io.open(os.getenv("TG_ROOT").."/out/car_accel_"..CAR..".csv","w")
fh:write("f,v,gear,top,delta,fuel,flags\n")
R.steer=function(f) return {x=true} end
R.run(F0+N,function(f)
  if f>=2990 then
    ww(0x1F8F,CAR) ww(0x1EE8,CAR*16)
    if f==3100 then for a=0x7E4000,0x7E7FFF do emu.write(a,0,mt) end end
    ww(0x1E8A,0) ww(0x1E8E,0) ww(0x1ED6,0) ww(0x1ED7,4000)
    for j=0,19 do local b=0x212+18*j
      if (b-0x212)~=rw(0x204) and (b-0x212)~=rw(0x206) then ww(b+2,0x6000) end end
  end
  if f>=2990 then ww(0x1F7A,0) ww(0x1F7C,0) end
  if f==F0 then ww(0x1E5A,0) ww(0x1E72,0) ww(0x1E6C,0) end
  if f>=F0 then ww(0x1E62,0xA7FF)
    fh:write(table.concat({f-F0,sw(rw(0x1E5A)),rw(0x1E72),rw(0x1EE2),rw(0x1E90),rw(0x1E62),rw(0x1EF5)},","),"\n") end
end,function() fh:close() end)
