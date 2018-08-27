
globalModule("cobre.math"):

  template def (fname: untyped): untyped =
    self.addfn("fname", [fltT], [fltT]):
      args.ret Value(kind: fltV, f: fname(args[0].f))

  self.addfn("pi", [], [fltT]):
    args.ret Value(kind: fltV, f: PI)

  self.addfn("e", [], [fltT]):
    args.ret Value(kind: fltV, f: E)

  self.addfn("sqrt2", [], [fltT]):
    args.ret Value(kind: fltV, f: sqrt(2.0))

  def abs
  def ceil
  def floor
  def round
  def trunc

  def ln
  def exp
  def sqrt
  def cbrt

  self.addfn("pow", [fltT, fltT], [fltT]):
    let r = pow(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("log", [fltT, fltT], [fltT]):
    let r = ln(args[0].f) / ln(args[1].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("mod", [fltT, fltT], [fltT]):
    let r = fmod(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)

  def sin
  def cos
  def tan

  self.addfn("asin", [fltT], [fltT]):
    let r = arcsin(args[0].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("acos", [fltT], [fltT]):
    let r = arccos(args[0].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("atan", [fltT], [fltT]):
    let r = arctan(args[0].f)
    args.ret Value(kind: fltV, f: r)

  self.addfn("atan2", [fltT, fltT], [fltT]):
    let r = arctan2(args[0].f, args[1].f)
    args.ret Value(kind: fltV, f: r)

  def sinh
  def cosh
  def tanh