
globalModule("auro.math"):

  template def (fname: untyped, str: string): untyped =
    self.addfn(str, [fltT], [fltT]):
      args.ret Value(kind: fltV, f: fname(args[0].f))

  self.addfn("pi", [], [fltT]):
    args.ret Value(kind: fltV, f: PI)

  self.addfn("e", [], [fltT]):
    args.ret Value(kind: fltV, f: E)

  self.addfn("sqrt2", [], [fltT]):
    args.ret Value(kind: fltV, f: sqrt(2.0))

  def abs, "abs"
  def ceil, "ceil"
  def floor, "floor"
  def round, "round"
  def trunc, "trunc"

  def ln, "ln"
  def exp, "exp"
  def sqrt, "sqrt"
  def cbrt, "cbrt"

  self.addfn("pow", [fltT, fltT], [fltT]):
    let r = pow(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("log", [fltT, fltT], [fltT]):
    let r = ln(args[0].f) / ln(args[1].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("mod", [fltT, fltT], [fltT]):
    let r = fmod(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)

  def sin, "sin"
  def cos, "cos"
  def tan, "tan"
  def arcsin, "asin"
  def arccos, "acos"
  def arctan, "atan"
  def sinh, "sinh"
  def cosh, "cosh"
  def tanh, "tanh"

  self.addfn("atan2", [fltT, fltT], [fltT]):
    let r = arctan2(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)