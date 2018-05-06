
$st = 1234

def rand
  # 4005 = 2*2*7*11*13 + 1
  # 165  = 3*5*11
  # 0x10000 = 2**16 = 65536
  $st = $st * 4005 + 165
  while $st >= 0x10000 do
    $st = $st - 0x10000
  end
  $st / 65536.0
end

count = 2000
i = 0
inside = 0

start = Time.now

while i < count do
  x = rand
  y = rand
  if x*x + y*y <= 1.0 then
    inside += 1
  end
  i += 1
end

fin = Time.now
time = fin - start

pi = 4.0 * inside / count

puts "#{count} samples, PI=#{pi} in #{time}s"

# 2000 samples, PI=3.144 in 0.359121647s
# Stupidly fast, 5x python and almost 7x lua

