-- Collision hooks: logs a before/after snapshot at each collision site of the original game.
--   BOT  : player rear-ends a bot (05:E56B..E584), bot hits player from behind (00:A2E8, bump_p1), object handlers (05:F6B3 REV, F6F5/F6F1 EDGE/SIDE)
-- driver (env MODE): chase = poke P1 lateral to bot-ahead + D (D sweeps) and P1 speed high; sweep = poke lateral sweep across the road, speed fixed (objects);
--                    behind = hold P1 slow so that bots catch up from behind (lateral = bot behind + D)
dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local TAG=os.getenv("TAG") or "chook"
local MODE=os.getenv("MODE") or "chase"
local N=tonumber(os.getenv("FR") or 6000)
local SP=tonumber(os.getenv("SP") or 6000)
local out=io.open(os.getenv("TG_ROOT").."/out/"..TAG..".txt","w")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
local function snap(tag,extra)
  local s=emu.getState()
  out:write(string.format("%d %s X=%04X Y=%04X A=%04X spd=%d steer=%d st2=%d lat=%d pos=%d eec=%d fwd=%d fl=%04X %s\n",R.f,tag,s["cpu.x"],s["cpu.y"],s["cpu.a"],r2(0x1E5A),sw(r2(0x1E7E)),sw(r2(0x1E82)),sw(r2(0x1E8A)),r2(0x1ED7),r2(0x1EEC),sw(r2(0x1E8E)),r2(0x1EF5),extra or ""))
end
local function botrec(x) return string.format("bot[id=%d lat=%d prog=%d spd=%d acc=%d tim=%d]",r2(0x212+x)&0x1F,sw(r2(0x214+x)),r2(0x219+x),r2(0x21C+x),sw(r2(0x21E+x)),r2(0x220+x)) end
FREECNT={0,0}
local function onexec(a,fn) emu.addMemoryCallback(fn, emu.callbackType.exec, a, a) end
-- player hits a bot ahead
onexec(0x05E4F5,function() snap("FRONT_A", "diff(half)="..sw(emu.getState()["cpu.a"])) end)
onexec(0x05E56B,function() local x=emu.getState()["cpu.x"] snap("FRONT_pre",botrec(x)) end)
onexec(0x05E584,function() local x=r2(0x204)+0 snap("FRONT_post","") end)
-- bot hits player (bump_p1 entry/exit); X here is DP view (slot+0x12)
onexec(0x00A30C,function() local x=emu.getState()["cpu.x"] snap("BEHIND_pre",botrec(x-18)) end)
onexec(0x00A2EE,function() local x=emu.getState()["cpu.x"] snap("BEHIND_post",botrec(x-18)) FREE=R.f+240 end)
-- object handlers (X = type*2)
local function oh(name) return function() local s=emu.getState() snap(name,string.format("type=%d diff=%d carry=%d",s["cpu.x"]//2,sw(s["cpu.y"]),s["cpu.ps"]&1)) end end
onexec(0x05F6B3,oh("OBJ_REV"))
onexec(0x05F6F5,oh("OBJ_EDGE"))
onexec(0x05F6F1,oh("OBJ_SIDE"))
onexec(0x05F6F0,function() snap("OBJ_REV_ret","") if MODE=="sweep" and not FREE and FREECNT[1]<3 then FREE=R.f+200 FREECNT[1]=FREECNT[1]+1 end end)
onexec(0x05F728,function() snap("OBJ_EDGE_ret","") if MODE=="sweep" and not FREE and FREECNT[2]<3 then FREE=R.f+200 FREECNT[2]=FREECNT[2]+1 end end)
-- group object collision result and road-edge wall
onexec(0x05D720,function() snap("GROUP_hit","") end)
onexec(0x05D820,function() snap("WALL_R","") end)
onexec(0x05D838,function() snap("WALL_L","") end)
R.steer=function(f) return {x=true} end
local TRACK=tonumber(os.getenv("TRACK") or -1)
local len
local D=0
R.run(3000+N,function(f)
  if TRACK>=0 and f>=1500 and f<2900 then emu.write(0x1F06,TRACK,mt) end
  if f<3040 then return end
  len=r2(0x200)
  local y=r2(0x204)
  local pos=r2(0x1ED7)
  if MODE=="chase" then
    local best,bd=nil,99999
    for j=0,19 do local Y=18*j
      if Y~=y and r2(0x21C+Y)~=0 then
        local d=(r2(0x219+Y)-pos)%len
        if d>0 and d<bd then best,bd=Y,d end end end
    D=(((f//6)%48)-24)*250
    if best then w2(0x1E8A,(sw(r2(0x214+best))+D)&0xFFFF) end
    local sp=SP
    w2(0x1E5A,sp)
  elseif MODE=="behind" then
    local best,bd=nil,99999
    for j=0,19 do local Y=18*j
      if Y~=y and r2(0x21C+Y)~=0 then
        local d=(pos-r2(0x219+Y))%len
        if d>0 and d<bd then best,bd=Y,d end end end
    D=(((f//6)%48)-24)*150
    if best then w2(0x1E8A,(sw(r2(0x214+best))+D)&0xFFFF) end
    if not (FREE and f<FREE) then w2(0x1E5A,tonumber(os.getenv("SLOW") or 1800)) end
    if FREE and f<FREE and f%6==0 then snap("TRACE",botrec(best or 0)) end
    if FREE and f>=FREE then FREE=nil end
  elseif MODE=="hold" then
    w2(0x1E8A,tonumber(os.getenv("LAT") or 0)&0xFFFF)
    if f==3100 then w2(0x1E5A,SP) end
    if f%6==0 then snap("TRACE","") end
  elseif MODE=="sweep" then
    if FREE and f<FREE then
      if f%(tonumber(os.getenv("TR") or 3))==0 then snap("TRACE","") end
    else
      if FREE then FREE=nil end
      local lat=math.floor(tonumber(os.getenv("AMP") or 14000)*math.sin(f/70))
      w2(0x1E8A,lat&0xFFFF)
      if f%3==0 then w2(0x1E5A,SP) end
    end
  end
end,function() out:close() end)
if os.getenv("WATCH") then
  local lo,hi=0,0
  emu.addMemoryCallback(function(a,v) out:write(string.format("%d W1E7E pc=%06X val=%02X addr=%04X\n",R.f,R.pc(),v,a)) end, emu.callbackType.write, 0x1E7E, 0x1E7F)
end
