-- Collision probe: per-frame player state + the car records just ahead / behind the player in the car list.
-- env: FR frames after 3000, MODE=straight (default: accelerate only) | POKE (see below), STEER=left/right bias, OUT name
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local N=tonumber(os.getenv("FR") or 600)
local TAG=os.getenv("TAG") or "collide"
local out=io.open(os.getenv("TG_ROOT").."/out/"..TAG..".csv","w")
local wr=emu.memType.snesWorkRam
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local brake=os.getenv("BRAKE_AT") and tonumber(os.getenv("BRAKE_AT"))
local POKE=os.getenv("POKE")   -- "frame:addr=val,..." applied once at that frame (WRAM addr)
local pokes={}
for fr,rest in (POKE or ""):gmatch("(%d+):([^;]+)") do
  pokes[tonumber(fr)]={} for a,v in rest:gmatch("(%x+)=(%-?%x+)") do table.insert(pokes[tonumber(fr)],{tonumber(a,16),tonumber(v,16)}) end end
out:write("f,tick,spd,steer,lat,pos,lap,e1eec,e1ef5,fwd,slot,A_id,A_lat,A_prog,A_spd,A_acc,A_tim,B_id,B_lat,B_prog,B_spd,B_acc,B_tim\n")
R.steer=function(f)
  local p={x=true}
  if os.getenv("DRIVE")=="left" then p.left=true elseif os.getenv("DRIVE")=="right" then p.right=true end
  if brake and f>=3000+brake then p.x=false p.y=true end
  return p
end
local function rec(y)
  if y<0 or y>=18*20 then return "-1,0,0,0,0,0,0" end
  return table.concat({R.rw(0x212+y)&0x1F, sw(R.rw(0x214+y)), R.rw(0x219+y), R.rw(0x21C+y), sw(R.rw(0x21E+y)), R.rw(0x220+y)},",")
end
R.run(3000+N,function(f)
  if pokes[f-3000] then for _,p in ipairs(pokes[f-3000]) do w2(p[1],p[2]) end end
  if f<3000 then return end
  local y=R.rw(0x204)
  out:write(table.concat({f,R.rd(0x1E90),R.rw(0x1E5A),sw(R.rw(0x1E7E)),sw(R.rw(0x1E8A)),R.rw(0x1ED7),R.rd(0x21B+y),R.rw(0x1EEC),R.rw(0x1EF5),sw(R.rw(0x1E8E)),y//18, rec(y+18), rec(y-18)},","),"\n")
end,function() out:close() end)
