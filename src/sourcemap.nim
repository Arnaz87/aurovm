
import options
import tables

import metadata

type
  PosInfo* = object of RootObj
    file*: Option[string]
    line*: Option[int]
    column*: Option[int]

  ItemInfo* = object of PosInfo
    name*: Option[string]
    index*: int

  ModuleInfo* = object of ItemInfo
  TypeInfo* = object of ItemInfo
  FunctionInfo* = object of ItemInfo

  PrivInstInfo = object of ItemInfo
  PrivRegInfo = object of ItemInfo

  InstInfo* = object of PrivInstInfo
    function*: ItemInfo

  CodeInfo* = object of FunctionInfo
    code: seq[PrivInstInfo]
    regs: seq[PrivRegInfo]

  SourceMap* = ref object of RootObj
    file*: Option[string]
    modules*: Table[int, ModuleInfo]
    types*: Table[int, TypeInfo]
    functions*: Table[int, CodeInfo]

proc newSourceMap* (): SourceMap =
  SourceMap(
    file: none(string),
    types: initTable[int, TypeInfo](),
    functions: initTable[int, CodeInfo](),
    modules: initTable[int, ModuleInfo]()
  )

proc newSourceMap* (node: Node): SourceMap =
  result = newSourceMap()

  if node["file"].isSome:
    result.file = some(node["file"].get[1].s)

  for item in node.tail:
    if item.isNamed("type"):
      var info = TypeInfo(index: item[1].n, file: result.file)
      if item["line"].isSome:
        info.line = some(item["line"].get[1].n)
      if item["column"].isSome:
        info.column = some(item["column"].get[1].n)
      result.types[info.index] = info
    if item.isNamed("function"):
      var fun = CodeInfo(index: item[1].n, file: result.file)
      if item["name"].isSome:
        fun.name = some(item["name"].get[1].s)
      if item["line"].isSome:
        fun.line = some(item["line"].get[1].n)
      if item["column"].isSome:
        fun.column = some(item["column"].get[1].n)
      fun.code = @[]
      if item["code"].isSome:
        for data in item["code"].get.tail:
          var inst = PrivInstInfo()
          inst.index = data[0].n
          inst.line = some(data[1].n)
          if data.children.len > 2:
            inst.column = some(data[2].n)
          fun.code.add(inst)
      result.functions[fun.index] = fun

proc getType* (self: SourceMap, index: int): TypeInfo =
  if self.types.hasKey(index): self.types[index]
  else: TypeInfo(index: index)

proc getFunction* (self: SourceMap, index: int): CodeInfo =
  if self.functions.hasKey(index): self.functions[index]
  else: CodeInfo(index: index)

proc getInst* (self: CodeInfo, index: int): InstInfo =
  var last = none(PrivInstInfo)
  for inst in self.code:
    if last.isNone or (inst.index <= index and inst.index > last.get.index):
      last = some(inst)
  if last.isSome:
    result.line = last.get.line
    result.column = last.get.column
  result.index = index
  result.file = self.file
  result.function = ItemInfo(
    name: self.name,
    index: self.index,
    file: self.file,
    line: self.line,
    column: self.column
  )

proc getFuncName (self: ItemInfo): string =
  if self.name.isSome: self.name.get
  else: "function #" & $self.index

proc getPosStr (self: PosInfo): string =
  result = ""
  if self.file.isSome:
    result = self.file.get
  if self.line.isSome:
    result &= ":" & $self.line.get
    if self.column.isSome:
      result &= ":" & $self.column.get

proc `$`*(self: InstInfo): string =
  result = self.function.getFuncName
  if self.line.isSome: result &= " (" & self.getPosStr & ")"
  else: result &= ": instruction #" & $self.index

proc `$`*(self: CodeInfo): string =
  result = self.getFuncName
  if self.line.isSome: result &= " (" & self.getPosStr & ")"




#[ Languages stack traces
Nim:
file(line)            function

Lua:
file:line: in function

Node:
at function (file:line:column)

Python:
File "file", line line, in function
  line-contents

Ruby:
from file:line in function

Java:
at function(file:line)
]#

