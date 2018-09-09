
import machine
import parse
import compile

import aurolib

import os
from strutils import replace

type Module = machine.Module

proc help () =
  # getAppFilename() me da el nombre completo del ejecutable,
  # paramStr(0) solo me da el comando usado (en linux al menos).
  echo "Usage: " & paramStr(0) & " [options] module {args}"
  echo()
  echo "  Runs the specified auro module."
  echo()
  echo "  The module is searched as a file matching the module name, replacing the"
  echo "  unit separator (0x1f) with a point. It's searched in the following order:"
  echo "   - The directories passed in command arguments, in the reverse order"
  echo "   - The current directory"
  echo "   - The module installation path: $HOME/.auro/modules"
  echo()
  echo "  All subsequent imported modules are loaded the same way."
  echo()
  echo "Options:"
  echo "  -h  --help    prints this help"
  echo "  -v --version  prints the version information"
  echo "  --install     install the file module on the system"
  echo "  --remove      removes a module from system"
  echo "  --dir dir     adds the directory to the search list"
  quit(QuitSuccess)

if paramCount() == 0: help()

type Mode = enum run_mode, install_mode, remove_mode

var search_list = @[getEnv("HOME") & "/.auro/modules", "."]

var mode = run_mode
var main_module_name: string = nil
var add_dir = false
for p in commandLineParams():
  if auroargs.len < 1:
    if p == "--help" or p == "-h": help()
    if p == "--version" or p == "-v":
      echo "Auro 0.6"
      quit(QuitSuccess)
    if p == "--dir": add_dir = true
    elif p == "--install": mode = install_mode
    elif p == "--remove": mode = remove_mode
    elif p[0] == '-':
      echo "Unknown option " & p
      quit(QuitFailure)
    elif add_dir:
      search_list.add(p)
      add_dir = false
    else:
      main_module_name = p
      auroargs.add(p)
  else: auroargs.add(p)
auroexec = paramStr(0)

let mod_path = getEnv("HOME") & "/.auro/modules"

if mode != run_mode:
  let target = mod_path & "/" & main_module_name

  case mode
  of install_mode:
    createDir(mod_path)
    copyFile(main_module_name, target)
    echo "Installed module at " & target
  of remove_mode:
    removeFile(target)
    echo "Removed module at " & target
  else: discard

  quit(QuitSuccess)

proc compile_file (file: File, name: string): Module =
  proc read_byte(): uint8 =
    let L = file.readBuffer(result.addr, 1)
    if L != 1: raise newException(IOError, "cannot read byte")
  let parsed = parse(read_byte, name)
  try:
    return compile(parsed, name)
  except CompileError:
    echo "Error in module " & name
    echo getCurrentExceptionMsg()
    quit(QuitFailure)

proc module_loader (name: string): Module =
  var filename: string = name.replace('\x1f', '.')
  for i in 1 .. search_list.len:
    var path = search_list[^i] & "/" & filename
    if fileExists(path):
      let file = open(path)
      return compile_file(file, name)

set_module_loader(module_loader)

let main_module = module_loader(main_module_name)
if main_module.isNil:
  echo "Module " & main_module_name & " not found"
  quit(QuitFailure)
machine_modules.add(main_module)

let main_item = main_module["main"]
if main_item.kind != machine.fItem:
  echo "main function not found in " & main_module_name
  quit(QuitFailure)

try:
  discard main_item.f.run(@[])
except UserError:
  echo "Error: ", getCurrentExceptionMsg()
  print_trace()
  quit(QuitFailure)
except Exception:
  var e = getCurrentException()
  echo "FATAL: ", e.name, ": ", e.msg
  echo e.getStackTrace()
  
  echo "Auro Stack:"
  print_trace()
  echo()
  print_lowlevel()
  quit(QuitFailure)
