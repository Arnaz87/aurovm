--[ [
function sum (a, b)
  return a+b
end

function mul (a, b)
  return a*b
end
--]]

sel = "sum"

if sel == "sum"
then
  fun = sum
else
  fun = mul
end

print(fun(2, 3))