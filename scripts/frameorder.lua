dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local log={}
local on=false
emu.addMemoryCallback(function(a,v)
  if on then log[#log+1]=a end
end, emu.callbackType.exec, 0x000000, 0xFFFFFF)
R.steer=function(f) return {x=true} end
R.run(3601,function(f)
  if f==3600 then on=false end
  if f==3599 then on=true end
end,function()
  local fh=io.open(os.getenv("TG_ROOT").."/out/frameorder.txt","w")
  -- compress into runs of consecutive-ish addresses
  local start,prev
  for _,a in ipairs(log) do
    if prev and a>prev and a-prev<=4 then prev=a
    else
      if start then fh:write(string.format("%06X-%06X\n",start,prev)) end
      start=a prev=a
    end
  end
  if start then fh:write(string.format("%06X-%06X\n",start,prev)) end
  fh:close()
  print("n",#log)
end)
