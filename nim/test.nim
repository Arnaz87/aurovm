type
  Inst = ref object of RootObj
    a: int
  Call = ref object of Inst
    b: int

method lol(i: Inst) =
  echo "Inst " & $i.a
method lol(i: Call) =
  echo "Call " & $i.a & ", " & $i.b

var a: Inst = Inst()
var b: Call = Call()
a.a = 1
b.a = 3
b.b = 4
lol(a)
lol(b)
a = b
lol(a)