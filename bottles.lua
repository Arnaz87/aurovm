bottles = 5

while bottles > 0 do
  if bottles == 1 then plural = " bottle"
  else plural = " bottles" end

  print(bottles .. plural .. " of beer on the wall")
  print(bottles .. plural .. " of beer")
  print("Take one down, pass it around")
  bottles = bottles - 1
  print(bottles .. plural .. " of beer on the wall.")
  print("")
end