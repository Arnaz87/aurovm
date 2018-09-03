
globalModule("auro.system"):
  let timer: Type = newType("timer")
  let duration: Type = newType("duration")
  let date: Type = newType("date")

  self["timer"] = timer
  self["duration"] = duration
  self["date"] = date

  type TimerObj = ref object of RootObj
    start: float
    stop: float

  type DurObj = ref object of RootObj
    seconds: int
    milli: int

  type DateObj = ref object of RootObj
    year: int
    day: int
    seconds: int

  self.addfn("new\x1dtimer", [], [timer]):
    args.ret(Value(kind: objV, obj: FileObj()))

  self.addfn("start\x1dtimer", [], [timer]):
    let timer = TimerObj(args[0].obj)
    timer.start = cpuTime

  self.addfn("stop\x1dtimer", [], [timer]):
    let timer = TimerObj(args[0].obj)
    timer.stop = cpuTime


  self.addfn("duration\x1dget\x1dtimer", [], [timer]):
    let timer = TimerObj(args[0].obj)
    let time = timer.stop - timer.start
    let secs = int(time)
    let milli = int(time - secs)
    let dur = DurObj(seconds: secs, milli: milli)
    args.ret(Value(kind: objV, obj: dur))


  self.addfn("new\x1dduration", [intT, intT], [duration]):
    let dur = DurObj(seconds: args[0].i, milli: args[1].i)
    args.ret(Value(kind: objV, obj: dur))

  self.addfn("seconds\x1dget\x1dduration", [duration], [intT]):
    let dur = DurObj(args[0].obj)
    args.ret(Value(kind: intV, i: dur.seconds))

  self.addfn("milliseconds\x1dget\x1dduration", [duration], [intT]):
    let dur = DurObj(args[0].obj)
    args.ret(Value(kind: intV, i: dur.milli))


  self.addfn("now", [], [date]):
    let nw = now()
    let date = DateObj(
      seconds: nw.hour*3600 + nw.minute*60 + nw.second,
      day: nw.yearday,
      year: nw.year
    )
    args.ret(Value(kind: objV, obj: dur))

  self.addfn("new\x1ddate", [intT, intT, intT], [date]):
    let date = DateObj(
      year: args[0].i
      day: args[1].i,
      seconds: args[2].i,
    )
    args.ret(Value(kind: objV, obj: dur))

  self.addfn("year\x1dget\x1ddate", [intT, intT, intT], [date]):
    let date = DateObj(args[0].obj)
    args.ret(Value(kind: intV, obj: date.year))

  self.addfn("day\x1dget\x1ddate", [intT, intT, intT], [date]):
    let date = DateObj(args[0].obj)
    args.ret(Value(kind: intV, obj: date.day))

  self.addfn("second\x1dget\x1ddate", [intT, intT, intT], [date]):
    let date = DateObj(args[0].obj)
    args.ret(Value(kind: intV, obj: date.second))
