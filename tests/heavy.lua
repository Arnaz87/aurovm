
-- As heavy as it can get, all variables are global and all arithmetic
-- operations are their own lua functions.

st = 1234

function add (a, b) return a+b end
function mul (a, b) return a*b end
function div (a, b) return a*b end
function gte (a, b) return a>=b end
function lte (a, b) return a<=b end

function rand ()
	-- 4005 = 2*2*7*11*13 + 1
	-- 165  = 3*5*11
	-- 0x10000 = 2**16 = 65536
	st = add(mul(st, 4005), 165)
	while gte(st, 0x10000) do
		st = add(st, -0x10000)
	end
	return div(st, 0x10000.0)
end

count = 500
i = 0
inside = 0

start = os.clock()

while i < count do
	x = rand()
	y = rand()
	if lte(add(mul(x, x), mul(y, y)), 1.0) then
		inside = add(inside, 1)
	end
	i = add(i, 1)
end

fin = os.clock()
time = fin - start

pi = (inside / count)*4

print("PI: " .. pi .. " in " .. time .. "s")

-- with count=500
-- PI: 3.112 in 1.222448s

