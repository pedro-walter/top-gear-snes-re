-- Full loop on the randomizer ROM: menu -> PLAY (seed fixed or random) -> race (autopilot) -> results -> menu.  env: SEED (hex, optional), MAXF, SHOTS (comma list)
local ROOT=os.getenv("TG_ROOT")
local mt=emu.memType.snesMemory
local wr=emu.memType.snesWorkRam
local SEED=os.getenv("SEED") and tonumber(os.getenv("SEED"),16)
local MAXF=tonumber(os.getenv("MAXF") or 20000)
local TAG=os.getenv("TAG") or "loop"
local shots={}
for s in (os.getenv("SHOTS") or ""):gmatch("%d+") do shots[tonumber(s)]=true end
local STEP=tonumber(os.getenv("STEP") or 1000)
local function w2(a,v) emu.write(a,v&0xFF,wr) emu.write(a+1,(v>>8)&0xFF,wr) end
local function r2(a) return emu.read(a,wr)|(emu.read(a+1,wr)<<8) end
local function rw(a) return emu.read(a,mt)|(emu.read(a+1,mt)<<8) end
local function sw(v) if v>=0x8000 then return v-0x10000 end return v end
local f=0
local log=io.open(ROOT.."/out/"..TAG..".txt","w")
emu.addMemoryCallback(function() log:write(string.format("%d race_init: final_pos_p1=%04X p2=%04X flag1FF2=%d\n",f,rw(0x1F00),rw(0x1F02),rw(0x1FF2))) end, emu.callbackType.exec, 0x00A558, 0x00A558)
emu.addMemoryCallback(function() log:write(string.format("%d   grid: player slot=%d (0=rear) rank0=%d\n",f,rw(0x204)//18,rw(0x1E7A))) log:flush() end, emu.callbackType.exec, 0x00A66B, 0x00A66B)
emu.addMemoryCallback(function() log:write(string.format("%d race_exit: final_pos_p1=%04X rank=%d\n",f,rw(0x1F00),rw(0x1E7A))) log:flush() end, emu.callbackType.exec, 0x008834, 0x008834)
local ev={ {1300,"start"},{1420,"start"}, {1600,"down"},{1620,"down"},{1640,"down"},{1660,"down"},{1700,"a"} }
FIN0=nil
APR={} for t in (os.getenv('APRESS') or '100,300,500'):gmatch('%d+') do APR[#APR+1]=tonumber(t) end
local function shot(name)
  local fh=io.open(ROOT.."/out/"..TAG.."_"..name..".png","wb") fh:write(emu.takeScreenshot()) fh:close()
end
emu.addEventCallback(function()
  local p={}
  for _,e in ipairs(ev) do if f>=e[1] and f<e[1]+6 then p[e[2]]=true end end
  if f>=3000 then
    local fin=rw(0x1EB0)
    if fin>=10 then
      FIN0=FIN0 or f
      local d=f-FIN0
      for _,t in ipairs(APR) do if d>=t and d<t+6 then p.a=true p.start=(math.floor(t/100)%2==0) end end
    else
      p.x=true
      local lat=sw(rw(0x1E8A))
      if lat>1200 then p.left=true elseif lat<-1200 then p.right=true end
    end
  end
  emu.setInput(p,0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if os.getenv('PREV') and f>=2300 and f<2440 then emu.write(0x1F00,tonumber(os.getenv('PREV')),mt) emu.write(0x1F01,0,mt) emu.write(0x1FF2,1,mt) end
  if os.getenv('LAPS1') and f>=2600 and f<2700 then emu.write(0x1E56,0,mt) end
  if SEED and f>=1000 and f<1500 then w2(0x1F800,SEED&0xFFFF) w2(0x1F802,(SEED>>16)&0xFFFF) w2(0x1F804,1) w2(0x1F806,0xA55A) end
  if f%STEP==0 or shots[f] then
    local s=emu.getState()
    log:write(string.format("%d seed=%04X%04X mode=%d track=%d laps=%d len=%d fin=%d pc=%02X:%04X\n",f,r2(0x1F802),r2(0x1F800),r2(0x1F804),emu.read(0x1F06,mt),rw(0x1E56),rw(0x200),rw(0x1EB0),s["cpu.k"],s["cpu.pc"]))
    log:flush()
  end
  if shots[f] then shot(tostring(f)) end
  if f>=MAXF then log:close() emu.stop(0) end
end, emu.eventType.endFrame)
