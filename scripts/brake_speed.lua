dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
-- steady speed with accelerate vs accelerate+brake, per gear (manual gear: R = shift up)
local out=io.open(os.getenv("TG_ROOT").."/out/brake_speed.txt","w")
local MODE=tonumber(os.getenv("MODE") or "0")   -- 0: X only, 1: X + Y(brake) after 700 frames in each gear
R.steer=function(f)
  local p={x=true}
  local t=f-3000
  local ph=t%900
  if ph==300 or ph==600 then p.r=false end
  if ph>=0 and ph<6 and t>0 then p.r=true end   -- shift up at start of each 900 frame block
  if MODE==1 and ph>=450 then p.y=true end
  -- keep centred crudely
  local lat=R.rw(0x1E8A); if lat>=0x8000 then lat=lat-0x10000 end
  if lat>2500 then p.left=true elseif lat<-2500 then p.right=true end
  return p
end
R.run(3000+900*5,function(f)
  local t=f-3000
  if t>0 and t%60==0 then
    out:write(string.format("f=%d gear=%d spd=%d kmh=%d fuel=%d top=%d lat=%d pos=%d 108=%04X nitro=%04X\n",t,R.rw(0x1E72),R.rw(0x1E5A),(R.rw(0x1E5A)*24)>>10,R.rw(0x1E62),R.rw(0x1EE2),(function() local l=R.rw(0x1E8A) if l>=0x8000 then l=l-0x10000 end return l end)(),R.rw(0x1ED6),R.rw(0x108),R.rw(0x1E6C)))
  end
end,function() out:close() end)
