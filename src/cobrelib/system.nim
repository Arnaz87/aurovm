
# Investigar sobre las librerías POSIX, unistd.h, tienen funciones muy interesantes

globalModule("cobre.system"):
  self.addfn("readline", mksig([], [strT])):
    var line = stdin.readLine()
    args.ret Value(kind: strV, s: line)

  self.addfn("read", mksig([intT], [bufT])):
    let size = args[0].i
    var buf = newSeq[byte](size)
    let redd = stdin.readBytes(buf, 0, size)
    if redd < size: buf = buf[0..<redd]
    args.ret(Value(kind: binV, bytes: buf))

  self.addfn("write", mksig([bufT], [])):
    let buf = args[0].bytes
    let written = stdout.writeBytes(buf, 0, buf.len)
    if written != buf.len:
      raise newException(Exception, "Couldn't write to stdout")

  self.addfn("println", [strT], []): echo args[0].s

  self.addfn("exit", [intT], []): quit(args[0].i)

  self.addfn("exec", mksig([strT], [intT])):
    let cmd = args[0].s
    var p = startProcess(command = cmd, options = {poEvalCommand})
    let code = p.waitForExit()
    args.ret Value(kind: intV, i: code)

  self.addfn("arg0", [], [strT]):
    args.ret Value(kind: strV, s: cobreexec)

  self.addfn("argc", mksig([], [intT])):
    args.ret Value(kind: intV, i: cobreargs.len)

  self.addfn("argv", mksig([intT], [strT])):
    args.ret Value(kind: strV, s: cobreargs[args[0].i])

  self.addfn("env", mksig([strT], [strT])):
    args.ret Value(kind: strV, s: getEnv(args[0].s))

  self.addfn("error", mksig([strT], [])):
    raise newException(Exception, args[0].s)