
import time

st = 1234

def rand ():
  # 4005 = 2*2*7*11*13 + 1
  # 165  = 3*5*11
  # 0x10000 = 2**16 = 65536
  global st
  st = st * 4005 + 165
  while st >= 0x10000:
    st = st - 0x10000
  return st / 0x10000

count = 2000
i = 0
inside = 0

start = time.clock()

while i < count:
  x = rand()
  y = rand()
  if x*x + y*y <= 1.0:
    inside = inside+1
  i = i+1

fin = time.clock()
time = fin - start

pi = (inside / count)*4

print(str(count) + " samples, PI=" + str(pi) + " in " + str(time) + "s")

# 2000 samples, PI=3.144 in 1.88388991355896s
# faster than lua, which was a surprise to me

