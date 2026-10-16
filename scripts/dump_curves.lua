dofile(os.getenv("TG_ROOT").."/scripts/common.lua")
local out=io.open(os.getenv("TG_ROOT").."/out/curves_cur.txt","w")
R.run(3100,function(f)
  if f==3100 then
    local n=R.rw(0x1F06)
    out:write("track "..n.."\n")
    for k=0,2047 do
      local v=R.rw(0x7E4C00+2*k) if v>=0x8000 then v=v-0x10000 end
      out:write(v.." ")
    end
    out:close()
  end
end)
