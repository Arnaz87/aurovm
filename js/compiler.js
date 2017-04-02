
// Como nodejs y el navegador funcionan diferente, tengo que usar un solo
// archivo.

(function (exports, window) {

// Por ahora, solo puedo leer un solo módulo y usar Prelude
function parse (buffer) {
  var pos = 0;

  function fail (msg) { throw new Error(msg + ". at byte: " + pos.toString(16)); }
  function unsupported (msg) { fail("Unsupported: " + msg); }

  function readByte () {
    if (pos >= buffer.length) {
      fail("Unexpected end of file");
    }
    return buffer.readUInt8(pos++);
  }

  function readInt () {
    var n = 0;
    var byte = readByte();
    while (byte & 0x80) {
      n = (n << 7) | (byte & 0x7f);
      byte = readByte();
    }
    return (n << 7) | (byte & 0x7f);
  }

  function readStr () {
    var len = readInt();
    var str = "";
    while (len > 0) {
      var byte = readByte();
      str += String.fromCharCode(byte);
      len--;
    }
    return str;
  }

  var modules = [];
  var types = [];
  var prototypes = [];
  var rutines = [];
  var constants = [];

  function parseDeps () {
    var count = readInt();
    while (count>0) {
      var name = readStr();
      var paramCount = readInt();
      if (paramCount > 0) { fail("Dependency parameters not yet supported"); }
      modules.push(name);
      count--;
    }
  }

  function parseTypes () {
    var count = readInt();
    while (count>0) {
      var kind = readInt()
      switch (kind) {
        case 0:
          fail("Null type-kind");
          break;
        case 1:
          fail("Internal type-kind not yet supported");
          break;
        case 2:
          var modIndex = readInt() - 1;
          var module = modules[modIndex];
          var name = readStr();
          types.push(module + "." + name);
          break;
        case 3:
          fail("Use type-kind not yet supported");
          break;
        default:
          fail("Unrecognized type-kind: " + kind);
      }
      count--;
    }
  }

  function parsePrototypes () {
    var count = readInt();
    while (count > 0) {
      var proto = {
        ins: [],
        outs: []
      };

      var incount = readInt();
      while (incount > 0) {
        var index = readInt();
        proto.ins.push(types[index-1]);
        incount--;
      }

      var outcount = readInt();
      while (outcount > 0) {
        var index = readInt();
        proto.outs.push(types[index-1]);
        outcount--;
      }

      prototypes.push(proto);

      count--;
    }
  }

  function parseRutine (prototype) {
    var name = readStr();

    var regs = [];

    for (var i in prototype.ins ) { regs.push(regs[i]) }
    for (var i in prototype.outs) { regs.push(regs[i]) }

    var regCount = readInt();
    while(regCount>0) {
      var typeIndex = readInt() - 1;
      regs.push(types[typeIndex]);
      regCount--;
    }

    var insts = [];

    var instCount = readInt();

    function readVal () {return readInt() - 1;}

    while (instCount>0) {
      var inst = {};

      var index = readInt();
      switch (index) {
        case 0: inst = ["end"]; break;
        case 1:
          inst = ["cpy", readVal(), readVal()];
          break;
        case 2:
          inst = ["cns", readVal(), readVal()];
          break;
        case 3: unsupported("get instruction");
        case 4: unsupported("set instruction");
        case 5:
          inst = ["lbl", readInt()];
          break;
        case 6:
          inst = ["jmp", readInt()];
          break;
        case 7:
          inst = ["jif", readInt(), readVal()];
          break;
        case 8:
          inst = ["nif", readInt(), readVal()];
          break;
        default:
          if (index < 16) fail("Unrecognized instruction " + index);
          var index = index-16;

          var proto = prototypes[index];
          var rutine = rutines[index];
          if (rutine === undefined) { rutine = index; }

          var outs = [];
          var outCount = proto.outs.length;
          while (outCount > 0) {
            outs.push(readVal());
            outCount--;
          }

          var ins = [];
          var inCount = proto.ins.length;
          while (inCount > 0) {
            ins.push(readVal());
            inCount--;
          }

          inst = [rutine, outs, ins];
      }

      insts.push(inst);

      instCount--;
    }

    return {
      name: name,
      regs: regs,
      insts: insts,
      inCount: prototype.ins.length,
      outCount: prototype.outs.length
    };
  }

  function parseRutines () {
    for (var i in prototypes) {
      var prototype = prototypes[i];
      var kind = readInt();
      switch (kind) {
        case 0: fail("Null rutine kind"); break;
        case 1:
          var rutine = parseRutine(prototype);
          rutines.push(rutine);
          break;
        case 2:
          var modIndex = readInt() - 1;
          var module = modules[modIndex];
          var name = readStr();
          rutines.push(module + "." + name);
          break;
        case 3:
          fail("Use rutine kind not yet supported");
          break;
        default:
          fail("Unrecognized rutine kind: " + kind);
      }
    }
  }

  function parseConstants () {
    function addConst(type, val) { constants.push(val); }
    var count = readInt();
    while (count>0) {
      var kind = readInt();

      switch (kind) {
        case 0:
          addConst("null", null);
          break;
        case 1:
          var data = [];
          var size = readInt();
          while (size>0) {
            data.push(readByte());
            size--;
          }
          addConst("bin", data);
          break;
        case 2:
          var data = [];
          var size = readInt();
          while (size>0) {
            var index = readInt() - 1;
            if (index < constants.length) unsupported("constant lookahead");
            data.push(constants[index]);
            size--;
          }
          addConst("arr", data);
          break;
        case 3: unsupported("type constant");
        case 4: unsupported("rutine constant");
        default:
          if (kind<16) { fail("Unknown constant kind " + kind); }
          var index = kind-16;
          var rutine = rutines[index];

          switch (rutine) {
            case "Prelude.makeint":
              var index = readInt() - 1;
              var data = constants[index];
              var n = 0;
              for (i in data) {
                n = (n << 8) | data[i]
              }
              addConst("int", n);
              break;
            case "Prelude.makestr":
              var index = readInt() - 1;
              var data = constants[index];
              var str = "";
              for (i in data) {
                str += String.fromCharCode(data[i]);
              }
              addConst("str", str);
              break;
            default: unsupported("constant rutine call");
          }
      }

      count--;
    }
  }

  var magic = "";
  while (true) {
    byte = readByte();
    if (byte == 0) { break; }
    magic += String.fromCharCode(byte);
  }

  if (magic != "Cobre ~1") {
    fail("Invalid magic string: " + magic + ", expecting \"Cobre ~1\"");
  }

  parseDeps();
  parseTypes();
  parsePrototypes();
  parseRutines();
  parseConstants();

  return {
    modules: modules,
    types: types,
    prototypes: prototypes,
    rutines: rutines,
    constants: constants,
  };
}

function compile (data) {
  
  function fail (msg) { throw new Error(msg); }
  function unsupported (msg) { fail("Unsupported: " + msg); }

  var identation = 0;

  var _str = "";

  function writeLine (text) {
    for (var i = 0; i < identation; i++) {
      _str += "  ";
    }
    _str += text + "\n";
  }

  function joinStrings (count, sep, func) {
    var str = "";
    var first = true;
    for (var i = 0; i < count; i++) {
      if (first) {first = false;} else {str += sep;}
      str += func(i);
    }
    return str;
  }

  function reg(i) { return "reg_" + (i+1); }

  for (i in data.rutines) {
    var rutine = data.rutines[i];

    if (typeof(rutine.name) !== "string") continue;

    var argStr = joinStrings(rutine.inCount, ", ", function(i) {
      return "reg_" + i;
    });

    writeLine("function " + rutine.name + " (" + argStr + ") {");
    identation++;

    writeLine("var _lbl = 0;");
    writeLine("var _result;");

    for (var i = rutine.inCount; i < rutine.regs.length; i++) {
      writeLine("var reg_" + i + ";")
    }

    writeLine("while (_lbl !== null) {");
    writeLine("switch (_lbl) {")
    writeLine("case 0:");
    identation++;

    var constants = data.constants;
    var rutines = data.rutines;

    for (var i in rutine.insts) {
      var inst = rutine.insts[i];

      function writeBinop (op, a, b) {
        writeLine(
          "reg_" + inst[1][0] +
          " = "+(a? a : "reg_"+inst[2][0]) +
          " " + op +
          " "+(b? b: "reg_"+inst[2][1]) +
        ";");
      }

      function writeUnop (op) {
        writeLine(
          "reg_" + inst[1][0] +
          " = " + op +
          "reg_" + inst[2][0] +
        ";");
      }

      switch (inst[0]) {
        case "cpy":
          writeLine("reg_" + inst[1] + " = reg_" + inst[2] + ";")
          break;
        case "cns":
          var value = constants[inst[2]];
          var repr;
          switch (typeof(value)) {
            case "number": repr = String(value); break;
            case "string":
              repr = "\"";
              repr += value
                .replace(/"/g, "\\\"")
                .replace(/\\/g, "\\\\")
                .replace(/\n/g, "\\n");
              repr += "\"";
              break;
            case "boolean": repr = value?"true":"false"; break;
            default: fail("Unknown representation for constant " + value);
          }
          writeLine("reg_" + inst[1] + " = " + repr)
          break;
        case "lbl":
          identation--;
          writeLine("case " + inst[1] + ":");
          identation++;
          break;
        case "end":
          writeLine("_lbl = null; break;");
          break;
        case "jmp":
          writeLine("_lbl = " + inst[1] + "; break;");
          break;
        case "jif":
          writeLine("if (reg_" + inst[2] + ") {");
          identation++;
          writeLine("_lbl = " + inst[1] + "; break;");
          identation--;
          writeLine("}");
          break;
        case "nif":
          writeLine("if (!reg_" + inst[2] + ") {");
          identation++;
          writeLine("_lbl = " + inst[1] + "; break;");
          identation--;
          writeLine("}");
          break;
        case "Prelude.print":
          writeLine("console.log(reg_" + inst[2][0] + ");");
          break;
        case "Prelude.itos":
          writeLine(
            "reg_" + inst[1][0] +
            " = String(" + reg(inst[2][0]-1)+
          ");");
          break;
        case "Prelude.iadd":
          writeBinop("+");
          break;
        case "Prelude.isub":
          writeBinop("-");
          break;
        case "Prelude.eq":
          writeBinop("==");
          break;
        case "Prelude.gt":
          writeBinop(">");
          break;
        case "Prelude.gte":
          writeBinop(">=");
          break;
        case "Prelude.concat":
          writeBinop("+");
          break;
        case "Prelude.gtz":
          writeBinop(">", null, "0");
          break;
        case "Prelude.inc":
          writeBinop("+", null, "1");
          break;
        case "Prelude.dec":
          writeBinop("-", null, "1");
          break;
        default:
          var rut = inst[0];

          if (typeof(rut) == "string") {
            fail("Unknown rutine or instruction: " + rut)
          }
          if (typeof(rut) == "number") { rut = rutines[rut] }

          var argStr = joinStrings(rut.inCount, ", ", function (i) {
            return "reg_" + inst[2][i];
          })

          writeLine("_result = " + rut.name + "(" + argStr + ");")
          for (var i = 0; i < rut.outCount; i++) {
            writeLine("reg_" + inst[1][i] + " = _result[" + i + "];")
          }
      }
    }

    identation--;
    writeLine("}}")

    var retStr = joinStrings(rutine.outCount, ", ", function (i) {
      return "reg_" + (i + rutine.inCount);
    });

    writeLine("return [" + retStr + "];");
    identation--;
    writeLine("}");
  }

  writeLine("main();")

  return _str;
}

if (exports) {
  exports.parse = parse;
  exports.compile = compile;
}

})(
  (typeof(exports) == "undefined")?
  (window.Cobre = {}) : exports
);
