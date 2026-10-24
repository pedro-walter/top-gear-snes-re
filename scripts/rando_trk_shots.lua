-- X TRACKS row shots: main menu -> row 2, press Left (infinity), then Right x1..: shots after each step.  env TAG, STEPS (default 12)
local ROOT=os.getenv("TG_ROOT")
local TAG=os.getenv("TAG") or "trk"
local STEPS=tonumber(os.getenv("STEPS") or 12)
local sched,shots={},{}
local function press(f,b) for i=0,5 do sched[f+i]=b end end
local f=1300
press(f,"start") f=f+120 press(f,"start") f=f+180
press(f,"down") f=f+24 press(f,"down") f=f+40
press(f,"left") f=f+40 shots[f]=true f=f+10        -- infinity
for i=1,STEPS do press(f,"right") f=f+40 shots[f]=i f=f+10 end
local last=f
emu.addEventCallback(function()
  local p={} local b=sched[FR] if b then p[b]=true end emu.setInput(p,0)
end, emu.eventType.inputPolled)
FR=0
emu.addEventCallback(function()
  FR=FR+1
  if shots[FR] then local fh=io.open(ROOT.."/out/"..TAG.."_"..FR..".png","wb") fh:write(emu.takeScreenshot()) fh:close() print("shot",FR,shots[FR]) end
  if FR>=last then emu.stop(0) end
end, emu.eventType.endFrame)
