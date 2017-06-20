
window.compileParsed = (parsed, modules) ->
  fail = (msg) -> throw new Error(msg)
  fail "Unsupported cobre version" if parsed.magic.value != "Cobre ~1"
  mods = parsed.modules.map (mod) -> modules[mod.name.value]
  rutines = parsed.rutines.map (rut) ->
    switch rut.kind.value
      when "null" then fail "null rutine"
      when "import" then mods[rut.module_index.value][rut.name.value]
      when "internal"
        lbls = {}
        for i in [0...rut.instructions.length]
          inst = rut.instructions[i]
          if inst.type.value == "lbl"
            lbls[inst.lbl.value] = i
        insts = rut.instructions.map (inst) ->
          slf = switch inst.type.value
            when "end" then {}
            when "cpy"
              a: inst.reg_a.value
              b: inst.reg_b.value
            when "cns"
              a: inst.reg_a.value
              cns: inst.const.value
            when "get", "set"
              a: inst.reg_a.value
              b: inst.reg_b.value
              f: inst.field.value
            when "lbl" then {}
            when "jmp" then {i: lbls[inst.lbl.value]}
            when "jif", "nif"
              i: lbls[inst.lbl.value]
              a: inst.reg_a.value
            when "call"
              rut_index: inst.rutine_index.value
              ins:  inst.ins.map  (x) -> x.value
              outs: inst.outs.map (x) -> x.value
            else fail "unknown instruction #{inst.type.value}"
          slf.type = inst.type.value
          slf
        {
          module: null
          name: rut.name.value
          insts: insts
        }
      else fail "unknown kind #{rut.kind}"

  module =
    rutines: {}

  rutines.forEach (rut) ->
    unless typeof rut == "function" || rut.module?
      rut.module = module
      if rut.name
        module.rutines[rut.name] = rut
      rut.insts.forEach (inst) ->
        if inst.rut_index?
          inst.rutine = rutines[inst.rut_index]
        delete inst.rut_index

  module