import options

type
  NodeKind* = enum listNode, strNode, intNode
  Node* = object of RootObj
    case kind*: NodeKind
    of listNode: children*: seq[Node]
    of strNode: s*: string
    of intNode: n*: int

proc `$`*(nd: Node): string =
  case nd.kind
  of strNode: return '"' & nd.s & '"'
  of intNode: return $nd.n
  of listNode:
    result = "("
    var first = true
    for x in nd.children:
      if first: first = false
      else: result &= " "
      result &= $x
    result &= ")"

proc tail*(node: Node): seq[Node] =
  result = newSeq[Node](node.children.len - 1)
  for i in 1 .. node.children.high:
    result[i-1] = node.children[i]

proc `[]`*(nd: Node, index: int): Node =
  if nd.kind != listNode:
    raise newException(Exception, "Node is not a list: " & $nd)
  nd.children[index]

proc isNamed*(node: Node, name: string): bool =
  if node.kind == listNode and node.children.len > 0:
    let head = node.children[0]
    if head.kind == strNode and head.s == name:
      return true
  return false

proc `[]`*(nd: Node, key: string): Option[Node] =
  if nd.kind == listNode:
    for child in nd.children:
      if child.isNamed(key):
        return some(child)
  else: return none(Node)