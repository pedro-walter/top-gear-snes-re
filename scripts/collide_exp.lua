-- Controlled rear-end experiments: every TL frames, poke the car ahead of P1 (lateral = P1 lat + D, progress = P1 pos + DP, speed = SB, latspd 0)
-- and poke P1's speed to SP. Logs every frame with the trial parameters. env: TL (default 90), MODE=front|back
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local TAG=os.getenv("TAG") or "cexp"
local TL=tonumber(os.getenv("TL") or 90)
local MODE=os.getenv("MODE") or "front"
local out=io.open(os.getenv("TG_ROOT").."/out/"..TAG..".csv","w")
local wr=emu.memType.snesWorkRam
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function w2(a,v) emu.write(a,v&0xFFFF&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
local function rd(a) return emu.read(a,wr) end
local trials={}
if MODE=="front" then
  for _,sb in ipairs{1500,2500} do for _,sp in ipairs{5000} do for D=-6000,6000,1000 do trials[#trials+1]={D=D,SB=sb,SP=sp,DP=150} end end end
else  -- bot behind the player, catching up: bot speed SB high, player slow
  for _,sb in ipairs{3500} do for _,sp in ipairs{1500,3000} do for D=-5000,5000,1000 do trials[#trials+1]={D=D,SB=sb,SP=sp,DP=-150} end end end
end
out:write("trial,D,SB,SP,f,tick,spd,steer,lat,pos,e1eec,e1ef5,fwd,slot,T_id,T_lat,T_prog,T_spd,T_acc,T_tim\n")
R.steer=function(f) return {x=true} end
local cur=0
R.run(3200+TL*#trials+10,function(f)
  if f<3200 then return end
  local k=(f-3200)//TL+1
  local t=trials[k]
  if not t then return end
  local y=r2(0x204)
  local ty = (MODE=="front") and (y+18) or (y-18)
  if (f-3200)%TL==0 then
    -- set up the target record
    w2(0x214+ty, r2(0x1E8A)+t.D)
    w2(0x216+ty, 0)
    w2(0x219+ty, (r2(0x1ED7)+t.DP)&0xFFFF)
    w2(0x21C+ty, t.SB) w2(0x21E+ty,0) w2(0x220+ty,0)
    w2(0x1E5A, t.SP)
  end
  out:write(table.concat({k,t.D,t.SB,t.SP,f,rd(0x1E90),r2(0x1E5A),sw(r2(0x1E7E)),sw(r2(0x1E8A)),r2(0x1ED7),r2(0x1EEC),r2(0x1EF5),sw(r2(0x1E8E)),y//18,
    r2(0x212+ty)&0x1F, sw(r2(0x214+ty)), r2(0x219+ty), r2(0x21C+ty), sw(r2(0x21E+ty)), r2(0x220+ty)},","),"\n")
end,function() out:close() end)
