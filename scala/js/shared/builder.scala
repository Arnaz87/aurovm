package arnaud.cobre.backend.js

import scala.collection.mutable.{Map, Buffer}

object Builder {
  def build (program: arnaud.cobre.format.Program) = {
    import arnaud.cobre.format.meta
    import meta.{SeqItem, Item}
    import meta.implicits.OptItemOps

    val srcmap = new SeqItem(program.metadata)("source map")

    val rutines = Map[Int, Rutine]()
    val constants = Map[Int, Constant]()

    def buildRutine (rut: program.RutineDef) {
      val rutine = rutines(rut.index).asInstanceOf[RutineDef]

      val regMeta = srcmap("rutines")(rut.index.toString)("regs")

      def Reg(reg: rut.Reg) = new Register(
        index = reg.index,
        name = regMeta(reg.index.toString) collect {
          case item: SeqItem => item(1).str
        }
      )

      for (r <- rut.inregs)  rutine.vars.ins  += Reg(r)
      for (r <- rut.outregs) rutine.vars.outs += Reg(r)
      for (r <- rut.regs) rutine.vars += Reg(r)

      rut.code foreach {
        case rut.Cpy(a, b) =>
          rutine.stmts += Stmt.Assign(
            rutine.vars(a.index),
            Expr.Var(rutine.vars(b.index))
          )
        case rut.Cns(a, cns) =>
          rutine.stmts += Stmt.Assign(
            rutine.vars(a.index),
            Expr.Cns(constants(cns.index))
          )
        case rut.Ilbl(l) =>
          rutine.stmts += Stmt.Lbl(l.index)
        case rut.Jmp(l) =>
          rutine.stmts += Stmt.Jmp(l.index, Expr.True)
        case rut.Ifj(l, a) =>
          rutine.stmts += Stmt.Jmp( l.index,
            Expr.Var(rutine.vars(a.index))
          )
        case rut.Ifn(l, a) =>
          rutine.stmts += Stmt.Jmp( l.index,
            Expr.Not(Expr.Var(rutine.vars(a.index)))
          )
        case rut.Call(f, outs, ins) =>
          rutine.stmts += Stmt.MultiCall(
            rutines(f.index),
            outs map {r: rut.Reg =>
              rutine.vars(r.index)
            },
            ins map {r: rut.Reg =>
              Expr.Var(rutine.vars(r.index))
            }
          )
        case rut.End() => rutine.stmts += Stmt.End
      }
    }

    program.constants foreach {
      case _c@program.CallConstant(rut: program.Module#Rutine, args) =>
        //if rut.module.nm == "Prelude" =>
        def getBytes (const: program.Constant) = const match {
          case program.BinConstant(bytes) => bytes
        }
        rut.name match {
          case "makeint" =>
            val data = getBytes(args(0))
            var n = 0;
            for (b <- data) {
              n = (n << 8) | b
            }
            constants(_c.index) = Constant.Num(n)
          case "makestr" =>
            val data = getBytes(args(0))
            val bytes = data.map(_.asInstanceOf[Byte]).toArray
            val str = new String(bytes, "UTF-8")
            constants(_c.index) = Constant.Str(str)
        }
      case _: program.BinConstant =>
    }

    program.rutines foreach {
      case rut: program.RutineDef =>
        rutines(rut.index) = new RutineDef(rut.name match {
          case "" => None; case nm => Some(nm)
        })
      case rut: program.Module#Rutine =>
        rutines(rut.index) = ImportRutine(rut.module.nm, rut.name)
    }

    program.rutines foreach {
      case rut: program.RutineDef => buildRutine(rut)
      case _ =>
    }

    new Program(rutines.values.toBuffer, constants.values.toBuffer)
  }
}
