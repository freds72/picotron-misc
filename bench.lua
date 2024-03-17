n = 1024

local a=vec(1,2,3)

local b=vec(3,4,5)
local v={1}
-- calibrate
flip() 
local x=stat(1)
for i=1,n do end 
y=stat(1)
-- measure sqrt(i)
for i=1,n do
	--local j=v[1]
	a:add(b,true)
end

z=stat(1)
local unit=0.0073313782991202
print("empty loop: "..(y-x))
print("lua cycles: "..((z-y)-(y-x))/unit)
