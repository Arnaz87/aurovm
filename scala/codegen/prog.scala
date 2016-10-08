package arnaud.myvm.codegen

import collection.mutable.{ArrayBuffer, Buffer, Map, Set, Stack}
import arnaud.myvm.codegen.{Nodes => ND}

class ProgState () {

  val imports: Map[String, (String, String)] = Map()
  val procs: Map[String, ProcState] = Map()

  val constants: Map[String, Any] = Map()
  var constantCount: Int = 0
  def addConstant(value: Any): RegId = {
    constantCount += 1
    val nm = "$const$" + constantCount
    constants(nm) = value
    RegId(nm)
  }

  val globals: Map[String, RegId] = Map()

  def %% (tp: Node) {
    tp match {
      case ND.TypeSet(name, vl) =>
        vl match {
          case ND.Import(module, field) =>
            imports(name) = (module, field)
          case ND.Proc(params, body) =>
            val proc = new ProcState(this)
            proc.setParams(params)
            procs(name) = proc
            proc %% body
          // case _ => THROW_EXCEPTION
        }
      case ND.Block(nds) =>
        nds foreach (%% _)
      // case _ => THROW_EXCEPTION
    }
  }

  def compile(): arnaud.sexpr.Node = {
    import arnaud.sexpr._
    import arnaud.sexpr.Implicits._
    type Node = arnaud.sexpr.Node

    def NBuf(i: Int = 32): Buffer[Node] = new ArrayBuffer[Node](i)

    val mods: Set[String] = Set()
    val modules: Buffer[Node] = new ArrayBuffer[Node](8)
    val imported: Buffer[Node] = new ArrayBuffer[Node](32)
    val procnd: Buffer[Node] = new ArrayBuffer[Node](16)
    val structnd: Buffer[Node] = new ArrayBuffer[Node](32)
    val selfnd = NBuf(64)
    val constnd = NBuf(16)

    selfnd += "SELF"
    selfnd += ListNode("MAIN", "MAIN")


    imported += "Types"
    imports.foreach{ case(k,(m, f)) =>
      imported += ListNode(k, m, f)
      mods += m
    }

    modules += "Imports"
    mods.foreach{ modules += _ }

    structnd += "Structs"
    procnd += "Functions"
    procs.foreach{ case(name, procst) =>
      val regsnm = name + "$regs"
      val argsnm = name + "$args"

      val codeNode = new ArrayBuffer[Node](128)
      val regsNode = new ArrayBuffer[Node](128)
      regsNode += regsnm

      codeNode += "Code"
      procst.code.foreach{inst =>
        codeNode += (inst match {
          case Inst.Cpy(a, b) => ListNode("cpy", a, b)
          case Inst.Get(a, b, c) => ListNode("get", a, b, c)
          case Inst.Set(a, b, c) => ListNode("set", a, b, c)
          case Inst.New(a) => ListNode("new", a)
          case Inst.Call(a) => ListNode("call", a)

          case Inst.Lbl(l) => ListNode("lbl", l)
          case Inst.Jmp(l) => ListNode("jmp", l)
          case Inst.If (l, a) => ListNode("if" , l, a)
          case Inst.Ifn(l, a) => ListNode("ifn", l, a)
        })
      }
      codeNode += ListNode("end")

      regsNode += ListNode("SELF", "SELF")
      regsNode += ListNode("ARGS", argsnm)
      procst.regs.foreach{case (nm, tp) => regsNode += ListNode(nm, tp)}

      structnd += regsNode

      val argsNode = new ArrayBuffer[Node](8)
      argsNode += argsnm
      procst.params foreach {
        case (nm, tp) => argsNode += ListNode(nm, tp)
      }
      structnd += argsNode

      procnd += ListNode(name, argsnm, regsnm, codeNode)
    }

    constnd += "Constants"
    globals.foreach{ case(name, reg) => 
      selfnd += ListNode(reg.name, "Any")
    }
    constants.foreach{ case (name, v) =>
      selfnd += ListNode(name, "Any")
      val tp = v match {
        case _:String => "str"
        case _:Float => "num"
        case _:Double => "num"
        case _:Int => "num"
      }
      constnd += ListNode(name, tp, v.toString)
    }

    structnd += selfnd

    ListNode( modules, imported, structnd, procnd, constnd )
  }
}