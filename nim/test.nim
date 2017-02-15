type
  Node* = ref object of RootObj
  Literal* = ref object of Node
    x: int
  Name* = ref object of Node
    name: string
  Sum* = ref object of Node
    a: Node
    b: Node
  Sub* = ref object of Node
    a: Node
    b: Node

method eval* (n: Node): int {.base.} =
  raise newException(Exception, "Unimplemented eval")

method eval* (l: Literal): int =
  return l.x
method eval* (s: Sum): int =
  return s.a.eval() + s.b.eval()
method eval* (s: Sub): int =
  return s.a.eval() - s.b.eval()

echo eval(Sum(a: Literal(x:3), b: Literal(x:2)))