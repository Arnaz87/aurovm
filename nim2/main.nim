import os

import machine
import methods

import modules

import read

if paramCount() != 1:
  # getAppFilename() me da el nombre completo,
  # paramStr(0) solo me da el comando usado (en linux al menos).
  echo "Usage: " & paramStr(0) & " <file>"
  quit()

let filename = paramStr(1)
let module = parseFile(filename)

#for prc in module.procs:
#  echo $$prc

addState(module.procs[0])
run()

