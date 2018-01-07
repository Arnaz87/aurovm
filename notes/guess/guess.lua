
math.randomseed( os.time() )

local from = 1
local to = 100
local rand = math.random( from, to )
local guess = 0
local guesses = 0
 
repeat
  print("Guess the number: ")
  guesses = guesses + 1
  guess = tonumber( io.read() )
  if guess > rand then
    print("Too high!")
  elseif guess < rand then
    print("Too low!")
  else
    print("You got it!")
    print("It took you " .. guesses .. " guesses.")
  end
until guess == rand