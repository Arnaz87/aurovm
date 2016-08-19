import strutils

type Parser = ref object of RootObj
method eof(parser: Parser): bool {.base.} =
  raise newException(Exception, "Unimplemented Parser.eof")
method get(parser: Parser): char {.base.} =
  raise newException(Exception, "Unimplemented Parser.get")
method peek(parser: Parser): char {.base.} =
  raise newException(Exception, "Unimplemented Parser.peek")

type
  PeekKind = enum
    isKind, inKind, nisKind, ninKind, anyKind
  Peek = object
    parser: Parser
    result: bool
    rch: char
    case kind: PeekKind
    of isKind, nisKind: ch: char
    of inKind, ninKind: st: set[char]
    of anyKind: discard

proc initPeek(peek: var Peek, parser: Parser): bool =
  peek.parser = parser
  if parser.eof:
    return false
  else:
    peek.rch = parser.peek
    return true
proc peekIs(parser: Parser, ch: char): Peek =
  result.kind = isKind
  result.ch = ch
  if result.initPeek(parser):
    result.result = result.rch == ch
proc peekIsNot(parser: Parser, ch: char): Peek =
  result.kind = nisKind
  result.ch = ch
  if result.initPeek(parser):
    result.result = result.rch != ch
proc peekIn(parser: Parser, st: set[char]): Peek =
  result.kind = inKind
  result.st = st
  if result.initPeek(parser):
    result.result = result.rch in st
proc peekInNot(parser: Parser, st: set[char]): Peek =
  result.kind = ninKind
  result.st = st
  if result.initPeek(parser):
    result.result = result.rch notin st
proc peekAny(parser: Parser): Peek =
  result.kind = anyKind
  discard result.initPeek(parser)

proc eatBool(peek: Peek): bool =
  if peek.result:
    discard peek.parser.get
    return true
  return false

proc safeGet(parser: Parser, ch: var char): bool =
  try:
    ch = parser.get
    return true
  except:
    return false
proc getifin(parser: Parser, st: set[char]): char =
  var name: string
  if parser.eof: name = "<End of Parser>"
  elif parser.peek notin st: name = $parser.peek
  else: return parser.get
  let msg = "Expecting one of " & $st & ", and got " & name
  raise newException(Exception, msg)
proc getifin(parser: Parser, st: set[char], ch: var char): bool =
  if not parser.eof and parser.peek in st:
    ch = parser.get
    return true
  return false
proc consumeif(parser: Parser, ch: char): bool =
  if not parser.eof and parser.peek == ch:
    discard parser.get
    return true
  return false
proc expect(parser: Parser, st: set[char]): bool =
  return (not parser.eof) and (parser.peek in st)



type StrParser = ref object of Parser
  str: string
  pos: int
proc newStrParser (str: string): StrParser =
  return StrParser(str: str, pos: 0)
method eof(parser: StrParser): bool =
  return (parser.pos >= parser.str.len)
  # Mayor o igual por el \0 al final
  # Hay que arreglar esto porque esto solo lo hace C (terminar strings con \0)
method get(parser: StrParser): char =
  if parser.eof:
    raise newException(Exception, "End of Parser")
  result = parser.str[parser.pos]
  parser.pos = parser.pos + 1
method peek(parser: StrParser): char =
  if parser.eof:
    raise newException(Exception, "End of Parser")
  return parser.str[parser.pos]



proc parseComment(parser: Parser): string =
  if parser.peek != ';': return nil
  discard parser.get
  result = ""
  if parser.peekIs('(').eatBool:
    result.add('(')
    var parens = 1
    var ch: char
    while parens > 0 and parser.safeGet(ch):
      if ch == '(': parens.inc
      if ch == ')': parens.dec
      result.add('(')
  else:
    while parser.expect(AllChars - {'\x0A'}):
      result.add(parser.get)
    discard parser.getifin({'\x0A'})
proc consumeWhite(parser: Parser): int =
  result = 0
  while not parser.eof:
    var ch = parser.peek
    if ch == ';':
      result += parser.parseComment.len + 2 # ';' + '\n'
      continue
    if ch notin Whitespace:
      return
    result += 1
    discard parser.get()
proc parseString(parser: Parser): string =
  if parser.peek != '"': return nil
  discard parser.get
  result = ""
  while parser.expect(AllChars - {'"'}):
    if parser.consumeif('\\'):
      if parser.eof:
        raise newException(Exception, "End of Parser trying to parse an escape sequence")
      case parser.get
      of '"': result.add('"')
      of '\\': result.add('\\')
      of 'n': result.add('\x0A')
      of 't': result.add('\t')
      of 's': result.add(' ')
      else: discard
    else: result.add(parser.get)
  discard parser.getifin({'"'})
proc parseWord(parser: Parser): string =
  const notvalid = {'(', ')', '"', ';'} + Whitespace
  result = ""
  while not parser.eof and parser.peek notin notvalid:
    result.add(parser.get)


type Node* = ref object of RootObj
type Atom* = ref object of Node
  str*: string
type List* = ref object of Node
  children*: seq[Node]


proc str*(node: Node): string = return Atom(node).str
proc `[]`*(list: List, i: int): Node = return list.children[i]
proc `[]`*(node: Node, i: int): Node = return List(node).children[i]
iterator items*(node: Node): Node =
  let list = List(node)
  var i = 0
  while i < list.children.len:
    yield list.children[i]
    i.inc
proc head*(node: Node): Node = return List(node).children[0]
proc tail*(node: Node): seq[Node] =
  let children = List(node).children
  return children[1 .. children.high]
iterator tail*(node: Node): Node =
  let list = List(node)
  var i = 1
  while i < list.children.len:
    yield list.children[i]
    i.inc

proc quote(str: string): string =
  if str.contains({'"', '\\', '\L', '\t', ' '}):
    result = str
    result = result.replace("\\", "\\\\")
    result = result.replace("\"", "\\\"")
    result = result.replace("\x0A", "\\n")
    result = result.replace("\t", "\\t")
    return '"' & result & '"'
  else: return str

method nodeRepr*(node: Node): string {.base.} =
  return "<Unkown Node Type>"
method nodeRepr*(node: Atom): string =
  return node.str.quote
method nodeRepr*(node: List): string =
  result = "("
  var first = true
  for nd in node.children:
    if first: first = false
    else: result.add(" ")
    result.add(nd.nodeRepr)
  result.add(")")
proc `$`*(node: Node): string =
  result = "<Lisp "
  result.add(node.nodeRepr)
  result.add(">")

proc parseNode(parser: Parser): Node
proc parseNodeList(parser: Parser): seq[Node]

proc parseNode(parser: Parser): Node =
  discard parser.consumeWhite
  if parser.eof:
    raise newException(Exception, "Tried to parse Node, but found unexpected EOF")
  elif parser.peek == '"':
    return Atom(str: parser.parseString)
  elif parser.consumeif('('):
    result = List(children: parser.parseNodeList)
    discard parser.getifin({')'})
  else:
    return Atom(str: parser.parseWord)
proc parseNodeList(parser: Parser): seq[Node] =
  result = @[]
  discard parser.consumeWhite
  while not parser.eof and parser.peek != ')':
    result.add(parser.parseNode)
    discard parser.consumeWhite

proc parseSexpr*(str: string): Node =
  var parser = newStrParser(str)
  return parser.parseNode

proc parseSexpr*(file: File): Node =
  return parseSexpr(file.readAll)

when isMainModule:
  import parseopt2
  # parseopt tiene un bug que no escapa las comillas de un argumento.

  type Option = enum
    strOpt, fileOpt, nonOpt
  var str: string
  var option: Option = nonOpt

  var opts = initOptParser()

  opts.next
  while opts.kind != cmdEnd:
    if opts.kind == cmdShortOption:
      case opts.key
      of "i":
        opts.next
        if opts.kind == cmdArgument:
          str = opts.key
          option = strOpt
      of "f":
        opts.next
        if opts.kind == cmdArgument:
          str = opts.key
          option = fileOpt
    else: discard
    opts.next

  case option
  of nonOpt:
    echo "Usage: (-i <s-expr> | -f <filename>)"
    let demostr = """
      (a b
        (c d) e ;(comentario ((de) parentesis)) f
        g "h \" i" j ;comentario de línea
        (k
          ;(comentario
            (abarcando muchas
              (lineas)))
          (l m (n))
        )
      )
    """
    echo demostr
    echo parseSexpr(demostr)
  of strOpt:
    echo parseSexpr(str)
  of fileOpt:
    echo parseSexpr(open(str))

