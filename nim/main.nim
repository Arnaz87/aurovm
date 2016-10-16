import tables
import os
import sexpr
import strutils
import sequtils

include types
include methods
include machine

include prelude
#include lua

if paramCount() == 0:
  let mainArgs = Args(ins: @[], outs: @[])
  let mainRegs = newStruct("main-regs", @[
    ("a", NumberType),
    ("b", NumberType),
    ("r", NumberType),
    ("rs", StringType),])
  let mainInst = @[
    ICns("a", "a"),
    ICns("b", "b"),
    ICall(addCode, @["r"], @["a", "b"]),
    ICall(itosCode, @["rs"], @["r"]),
    ICall(printCode, @[], @["rs"]),
    IEnd ]
  let mainCode = newMachineCode("MAIN", mainArgs, mainRegs, mainInst)

  var moduleData = initTable[string, Value]()
  moduleData["a"] = NumberValue(4)
  moduleData["b"] = NumberValue(5)
  moduleData["MAIN"] = CodeValue(mainCode)

  var module = Module(name: "MAIN", data: moduleData)

  mainCode.module = module

  addModule(module)

  start()
else:
  let filename = paramStr(1)
  let fileNode = parseSexpr(open(filename))
  if not (fileNode of List):
    echo "Error: The contents of " & filename & " is not a valid List."
    quit(QuitFailure)

  let module = Module()

  # Los Structs a veces dependen de sí mismos, y de las funciones, así que
  # hay que crear el Struct, pero los tipos de sus campos se deben asignar
  # después de haber creado todos los tipos del módulo.
  type Future = tuple[tp: string, reg: string, val: string]
  type FuncDef = tuple[code: Code, outc: int, inc: int]
  var futures: seq[Future] = @[]

  var types = initTable[string, Type]()
  var funcs = initTable[string, FuncDef]()
  var constantsNode: seq[Node]

  for sectionNode in fileNode:
    case sectionNode.head.str
    of "Imports":
      discard # Por ahora se puede usar la tabla de módulos de la máquina
    of "Types":
      for typeNode in sectionNode.tail:
        let modData = modules[typeNode[1].str].data
        let typeVal = modData[typeNode[2].str]
        types[typeNode[0].str] = typeVal.tp
    of "Structs":
      for structNode in sectionNode.tail:
        let name = structNode.head.str
        var regs: seq[RegInfo] = @[]
        for regNode in structNode.tail:
          let rname = regNode[0].str
          regs.add((rname, NilType))
          futures.add((name, rname, regNode[1].str))
        let struct = newStruct(name, regs)
        types[name] = StructType(struct)
    of "FuncRefs":
      for funcNode in sectionNode.tail:
        let name = funcNode[0].str
        let module = modules[funcNode[1].str].data
        let code = module[funcNode[2].str].code
        let outc = funcNode[3].str.parseInt
        let inc  = funcNode[4].str.parseInt
        funcs[name] = (code: code, outc: outc, inc: inc)
    of "Functions":
      for functionNode in sectionNode.tail:
        let name = functionNode[0].str
        let regs = types[functionNode[1].str].struct
        let codeNode = functionNode[4]
        var args = Args(ins: nil, outs: nil)
        args.ins  = functionNode[2].tail.toStringSeq
        args.outs = functionNode[3].tail.toStringSeq
        # assert(codeNode.head.str == "Code")

        proc unrecognized(nm: string): Inst =
          raise newException(Exception, "Unrecognized instruction " & nm)

        var insts: seq[Inst] =
          codeNode.tail.map do (nd: Node) -> Inst:
            case nd.head.str
            of "cpy": ICpy(nd[1].str, nd[2].str)
            of "get": IGet(nd[1].str, nd[2].str, nd[3].str)
            of "set": ISet(nd[1].str, nd[2].str, nd[3].str)
            of "cns": ICns(nd[1].str, nd[2].str)
            of "new": INew(nd[1].str)
            #of "call": ICall(nd[1].str, nd.tail)
            of "lbl": ILbl(nd[1].str)
            of "jmp": IJmp(nd[1].str)
            of "if" : Iif (nd[1].str)
            of "ifn": Iifn(nd[1].str, nd[2].str)
            of "end": IEnd
            else:
              let tail = nd.tail.toStringSeq
              let fun = funcs[nd.head.str]
              let outs = tail[0 .. (fun.outc-1)]
              let ins = tail[fun.outc .. tail.high] # (func.outc+func.inc-1)
              ICall(fun.code, outs, ins)
            #else: unrecognized(nd.head.str)

        var code = newMachineCode(name, args, regs, insts)
        code.module = module
        funcs[name] = (code: code, outc: args.outs.len, inc: args.ins.len)
    of "Constants":
      # Las constantes se deben calcular después de todos los tipos
      constantsNode = sectionNode.tail
    of "Metadata":
      for dataNode in sectionNode.tail:
        case dataNode.head.str
        of "name": module.name = dataNode[1].str
        of "start": machineStart = funcs[dataNode[1].str].code
        else: discard
    else:
      echo "Unrecognized Section: " & sectionNode.head.str

  for fut in futures:
    # Los futures solo hacen falta para Structs.
    let struct = types[fut.tp].struct
    for i in 0..struct.info.high:
      if struct.info[i].s == fut.reg:
        struct.info[i].t = types[fut.val]

  module.data = initTable[string, Value]()

  for node in constantsNode:
    let name = node[0].str
    case node[1].str:
    of "num":
      let n = parseFloat(node[2].str)
      module.data[name] = NumberValue(n)
    of "str":
      let s = node[2].str
      module.data[name] = StringValue(s)
    of "type":
      module.data[name] = TypeValue(types[node[2].str])
    of "code":
      module.data[name] = CodeValue(funcs[node[2].str].code)
    else:
      echo "Unrecognized constant operation: " & node[1].str

  discard """
    # Imprimir el contenido del módulo
    echo "# Types"
    for k, v in types:
      echo k & ": " & v.dbgRepr(true)
    echo()
    echo "# Module"
    for val in module.data.data:
      echo val.dbgRepr
    echo()
  """

  addModule(module)

  start()




