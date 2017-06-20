
window.parse = (buffer) ->
  buffer = new Uint8Array(buffer)
  pos = 0

  fail = (msg) -> throw new Error("#{msg}. at byte #{pos}")
  unsupported = (msg) -> fail "Unsupported #{msg}"

  readByte = ->
    fail "Unexpected end of file" if pos >= buffer.length
    buffer[pos++]

  readInt = ->
    n = 0
    b = readByte()
    while b & 0x80
      n = (n << 7) | (b & 0x7f)
      b = readByte()
    (n << 7) | (b & 0x7f)

  readStr = ->
    len = readInt()
    str = ""
    while len > 0
      byte = readByte()
      str += String.fromCharCode byte
      len--
    str

  parse = (f) ->
    start = pos
    data = f()
    len = pos - start
    if typeof data != "object"
      data =
        value: data
    data.srcpos =
      start: start
      length: len
    data

  parseN = (n, f) -> parse f for [0...n]

  # Copia el srcpos de a a b
  copy_srcpos = (a, b) ->
    if typeof b != "object"
      b = value: b
    b.srcpos = a.srcpos
    b

  magic = parse ->
    str = ""
    loop
      byte = readByte()
      break if byte == 0
      str += String.fromCharCode byte
    str

  modules = parse ->
    count = readInt()
    parseN count, ->
      name = parse -> readStr()
      params = parse ->
        paramN = readInt()
        parseN paramN, -> readInt()
      {name, params}

  types = parse ->
    count = readInt()
    parseN count, ->
      k = parse readInt
      switch k.value
        when 0 then {kind: copy_srcpos(k, "null")}
        when 1 then unsupported "Internal type-kind"
        when 2 then parse ->
          module_index = parse -> readInt() - 1
          name = parse -> readStr()
          {kind: copy_srcpos(k, "import"), module_index, name}
        when 3 then unsupported "Use type-kind"
        else fail "Unrecognized type-kind #{k.value}"

  prototypes = parse ->
    count = readInt()
    parseN count, ->
      ins: parse ->
        n = readInt()
        parseN n, ->
          type_index: parse -> readInt()-1
      outs: parse ->
        n = readInt()
        parseN n, ->
          type_index: parse -> readInt()-1

  rutines = parse ->
    parseN prototypes.length, ->
      k = null
      kind = parse ->
        switch k=readInt()
          when 0 then "null"
          when 1 then "internal"
          when 2 then "import"
          when 3 then "use"
          else k
      switch k
        when 0 then {kind}
        when 1
          kind: kind
          name: parse -> readStr()
          reg_types: parse ->
            parseN readInt(), -> readInt() - 1
          instructions: parse ->
            parseN readInt(), ->
              pd = parse readInt
              with_pos = (x) -> copy_srcpos pd, x
              switch inst=pd.value
                when 0
                  type: with_pos "end"
                when 1
                  type: with_pos "cpy"
                  reg_a: parse -> readInt()-1
                  reg_b: parse -> readInt()-1
                when 2
                  type: with_pos "cns"
                  reg_a: parse -> readInt()-1
                  const: parse -> readInt()-1
                when 3
                  type: with_pos "get"
                  reg_a: parse -> readInt()-1
                  reg_b: parse -> readInt()-1
                  field: parse -> readInt()
                when 4
                  type: with_pos "set"
                  reg_a: parse -> readInt()-1
                  field: parse -> readInt()
                  reg_b: parse -> readInt()-1
                when 5
                  type: with_pos "lbl"
                  lbl: parse -> readInt()-1
                when 6
                  type: with_pos "jmp"
                  lbl: parse -> readInt()-1
                when 7
                  type: with_pos "jif"
                  lbl: parse -> readInt()-1
                  reg_a: parse -> readInt()-1
                when 8
                  type: with_pos "nif"
                  lbl: parse -> readInt()-1
                  reg_a: parse -> readInt()-1
                else
                  if inst < 16 then fail "unrecognized instruction #{inst}"
                  else
                    index = inst - 16
                    proto = prototypes[index]
                    outs = parse -> parseN proto.outs.length, -> readInt()-1
                    ins = parse ->parseN proto.ins.length, -> readInt()-1
                    {
                      type: with_pos "call"
                      rutine_index: with_pos index
                      outs: outs
                      ins: ins
                    }
        when 2
          kind: kind
          module_index: parse -> readInt()-1
          name: parse -> readStr()
        when 3 then unsupported "use rutine-kind"
        else fail "unknown rutine-kind #{kind}"

  constants = parse ->
    count = readInt()
    parseN count, ->
      k = null
      kind = parse ->
        switch k=readInt()
          when 0 then "null"
          when 1 then "binary"
          when 2 then "array"
          when 3 then "type"
          when 4 then "rutine"
          else k
      switch k
        when 0 then {kind}
        when 1
          kind: kind
          data: parse -> parseN readInt(), readByte
        when 2
          kind: kind
          data: parse -> parseN readInt(), readInt
        when 3 then {kind, type_index: parse readInt}
        when 4 then {kind, rutine_index: parse readInt}
        else
          if k<16 then fail "unknown constant-kind #{k}"
          index = k-16
          proto = prototypes[index]
          params = parse -> parseN proto.ins.length, -> readInt()-1
          {
            kind: copy_srcpos kind, "call"
            rutine_index: copy_srcpos kind, index
            const_indexes: params
          }

  parse_sexpr = ->
    parse ->
      n = readInt()
      if n & 1 
        chars = for [0 ... (n>>1)]
          String.fromCharCode readByte()
        chars.join("")
      else parse_sexpr() for [0 ... (n >> 1)]

  #metadata = "metadata"
  metadata = parse_sexpr()

  {magic, modules, types, prototypes, rutines, constants, metadata}
