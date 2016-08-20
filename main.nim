import tables
import os
import sexpr
import strutils

include types
include methods
include machine

include prelude

if paramCount() == 0:
  let mainArgs = newStruct("main-args", @[])
  let mainRegs = newStruct("main-regs", @[
    ("ARGS", StructType(mainArgs)),
    ("SELF", Type()),

    ("a", NumberType),
    ("b", NumberType),
    ("r", NumberType),
    ("rs", StringType),

    ("add", addType),
    ("print", printType),
    ("itos", itosType) ])
  let mainInst = @[
    IGet("a", "SELF", "a"),
    IGet("b", "SELF", "b"),
    INew("add"),
    ISet("add", "a", "a"),
    ISet("add", "b", "b"),
    ICall("add"),
    IGet("r", "add", "r"),
    INew("itos"),
    ISet("itos", "a", "r"),
    ICall("itos"),
    IGet("rs", "itos", "r"),
    INew("print"),
    ISet("print", "a", "rs"),
    ICall("print"),
    IEnd ]
  let mainCode = newMachineCode("MAIN", mainArgs, mainRegs, mainInst)
  let mainType = CodeType(mainCode)

  let moduleStruct = Struct(name: "MAIN", info: @[
    ("a", NumberType),
    ("b", NumberType),
    ("MAIN", mainType)
  ])
  let moduleType = StructType(moduleStruct)
  let moduleData = makeObject(moduleStruct)
  moduleData["a"] = NumberValue(4)
  moduleData["b"] = NumberValue(5)

  var module = Module(name: "MAIN", struct: moduleStruct, data: moduleData)

  mainRegs.info[1].t = moduleType
  mainCode.module = module

  addModule(module)

  start()
else:
  let filename = paramStr(1)
  let fileNode = parseSexpr(open(filename))
  if not (fileNode of List):
    echo "Error: The contents of " & filename & " is not a valid List."
    quit(QuitFailure)

  let module = Module(name: "MAIN")

  # Los Structs a veces dependen de sí mismos, y de las funciones, hay que 
  # crear el Struct pero los tipos se deben asignar después de haber 
  # creado todos los tipos.
  type Future = tuple[tp: string, reg: string, val: string]
  var futures: seq[Future] = @[]

  var types = initTable[string, Type]()
  var constantsNode: seq[Node]

  for sectionNode in fileNode:
    case sectionNode.head.str
    of "Imports":
      discard """
      No hace falta una tabla de imports porque se puede usar la propia tabla
      de módulos de la máquina. Pero solo por ahora.
      """
    of "Types":
      for typeNode in sectionNode.tail:
        let modData: Object = modules[typeNode[1].str].data
        let typeVal: Value  = modData[typeNode[2].str]
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
    of "Functions":
      for functionNode in sectionNode.tail:
        let name = functionNode[0].str
        let args = types[functionNode[1].str].struct
        let regs = types[functionNode[2].str].struct
        let codeNode = functionNode[3]
        # assert(codeNode.head.str == "Code")
        var insts: seq[Inst] = @[]
        for nd in codeNode.tail:
          var inst = case nd.head.str
            of "get": IGet(nd[1].str, nd[2].str, nd[3].str)
            of "set": ISet(nd[1].str, nd[2].str, nd[3].str)
            of "new": INew(nd[1].str)
            of "call": ICall(nd[1].str)
            of "lbl": ILbl(nd[1].str)
            of "jmp": IJmp(nd[1].str)
            of "if" : Iif (nd[1].str)
            of "ifn": Iifn(nd[1].str, nd[2].str)
            of "end": IEnd
            else: INop
          insts.add(inst)
        var code = newMachineCode(name, args, regs, insts)
        code.module = module
        types[name] = CodeType(code)
    of "Constants":
      # Esto se debe hacer después de haber hecho los tipos
      constantsNode = sectionNode.tail
    else:
      echo "Unrecognized Section " & sectionNode.head.str & ":"

  for fut in futures:
    # Los futures solo hacen falta para Structs, por lo que nunca se van a
    # referir a un tipo que no sea StructType.
    let struct = types[fut.tp].struct
    for i in 0..struct.info.high:
      if struct.info[i].s == fut.reg:
        struct.info[i].t = types[fut.val]

  module.struct = types["SELF"].struct
  module.data = makeObject(module.struct)

  for node in constantsNode:
    let name = node[0].str
    case node[1].str:
    of "num":
      let n = parseFloat(node[2].str)
      module.data[name] = NumberValue(n)
    of "type":
      module.data[name] = TypeValue(types[node[2].str])
    else:
      echo "Unrecognized operation: " & node[1].str

  echo "# Types"
  for k, v in types:
    echo k & ": " & v.dbgRepr(true)
  echo()
  echo "# Module"
  for val in module.data.data:
    echo val.dbgRepr
  echo()

  addModule(module)

  start()




