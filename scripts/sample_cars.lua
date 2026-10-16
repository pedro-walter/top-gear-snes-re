dofile("./scripts/common.lua")
local fh=io.open("./out/cars_"..(os.getenv("TAG") or "a")..".csv","w")
local STEP=tonumber(os.getenv("STEP") or 30)
local function rb(a) return emu.read(a,emu.memType.snesMemory) end
local function rw(a) return rb(a)|(rb(a+1)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
R.steer=function(f) local ph=(f//50)%2 local t={x=true} if ph==0 then t.left=true else t.right=true end if os.getenv("NOSTEER") then t={x=true} end return t end
R.run(tonumber(os.getenv("MAXF") or 9000),function(f)
  if f>=2940 and f%STEP==0 then
    local row={f, rw(0x1E5A), rw(0x1ED7), rw(0x1E7A), rw(0x1E5C), rw(0x1EDA), rw(0x204), rw(0x206), rw(0x200), rb(0x1E56), rw(0x1EB0), rw(0x1EAE)}
    for j=0,19 do
      local b=0x212+18*j
      row[#row+1]=string.format("%04X|%d|%d|%d|%d|%d|%d|%d|%d",rw(b),sw(rw(b+2)),sw(rw(b+4)),rb(b+6)+rw(b+7)*256,rb(b+9),sw(rw(b+10)),sw(rw(b+12)),rw(b+14),rw(b+16))
    end
    fh:write(table.concat(row,","),"\n")
  end
end,function() fh:close() end)
