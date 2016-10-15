type
  Obj = ref object
    nms: seq[string]
  Type = object
    i: int
    obj: Obj

const t = Type(i: 2, obj: Obj(nms: @["a", "b"]))