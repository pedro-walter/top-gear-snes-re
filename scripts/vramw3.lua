dofile("./scripts/common.lua")
local vr=emu.memType.snesVideoRam
local cnt={}
for _,a in ipairs({0x2115,0x2116,0x2117,0x2118,0x2119,0x420B,0x420C}) do
  emu.addMemoryCallback(function(addr,val) cnt[a]=(cnt[a] or 0)+1 end, emu.callbackType.write, a)
end
local out=io.open("./out/vramw3.txt","w")
local prev=""
R.steer=function(f) return {} end
R.run(2420,nil,function() out:close() end)
emu.addEventCallback(function()
  local t={} for a=0x1220,0x1440-1 do t[#t+1]=string.char(emu.read(a,vr)) end
  local s=table.concat(t)
  if s~=prev or R.f%200==0 then
    out:write(string.format("f=%d changed=%s 2116=%s 2118=%s 420B=%s\n",R.f,tostring(s~=prev),tostring(cnt[0x2116]),tostring(cnt[0x2118]),tostring(cnt[0x420B]))) prev=s end
end, emu.eventType.endFrame)
