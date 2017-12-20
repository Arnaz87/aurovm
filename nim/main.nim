import os

import machine
import parse
import compile
import cobrelib

if paramCount() != 1:
  # getAppFilename() me da el nombre completo,
  # paramStr(0) solo me da el comando usado (en linux al menos).
  echo "Usage: " & paramStr(0) & " <file>"
  quit()

let filename = paramStr(1)

var file = open(filename)
proc read_byte (): uint8 =
  let L = file.readBuffer(result.addr, 1)
  if L != 1: raise newException(IOError, "cannot read byte")
let parsed = parse(read_byte)

let compiled = compile(parsed)

let item = compiled["main"]
if item.kind == machine.fItem: discard item.f.run(@[])
else: raise newException(Exception, "main function not found")
