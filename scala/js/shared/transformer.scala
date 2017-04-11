package arnaud.cobre.backend.js

import collection.mutable
import collection.mutable.{Buffer, Set}

class Transformer (rutine: RutineDef) {

  def propagateVars () {
    // De aquí en adelante se asume que todos los registros temporales,
    // es decir los que no tienen nombre, están en forma SSA
    val temps = rutine.vars.set filter (_.name.isEmpty)

    // Cuenta los usos de todas las variables, antes de la transformación
    object Uses {
      val map = collection.mutable.Map[Register, Int]()
      def apply (reg: Register) = (map get reg) getOrElse 0

      private def count (reg: Register) { map(reg) = apply(reg)+1 }
      private def countExpr (expr: Expr) { expr match {
        case Expr.Var(reg) => count(reg)
        case Expr.Call(_, rs) => rs map countExpr
        case Expr.Not(expr) => countExpr(expr)
        case Expr.Cns(_) =>
        case Expr.True =>
      } }

      rutine.stmts foreach {
        case Stmt.Assign(_, expr) => countExpr(expr)
        case Stmt.Call(_, args) => args foreach countExpr
        case Stmt.MultiCall(_, _, args) => args foreach countExpr
        case Stmt.Jmp(_, expr) => countExpr(expr)
        case _ =>
      }
    } 

    // Selecciona el primer valor que se ha asigna a las temporales.
    // Como se usa SSA, el primer valor es el único valor.
    // Si la asignación de un registro se hizo con multicall, o con
    // cualquier cosa que no sea una asignación simple, no se procesa,
    // esto se indica con None.
    val values = (temps map {reg =>
      var vals = rutine.stmts collect {
        case Stmt.Assign(`reg`, value) => value
      }
      (reg -> vals.headOption)
    }).toMap

    // Todas las variables para eliminar
    val toElim: Set[Register] = temps filter {reg: Register =>
      (Uses(reg) <= 1) && (values(reg) != None)
    }

    // La función más importante. Recursivamente remplaza las temporales
    // que solo tiene un uso por el valor que se descubrió arriba
    def propagate (expr: Expr): Expr = expr match {
      case Expr.Var(reg) if toElim(reg) =>
        propagate(values(reg).get)
      case v@Expr.Var(reg) => v
      case Expr.Call(rut, rs) => Expr.Call(rut, rs map propagate)
      case Expr.Not(expr) => Expr.Not(propagate(expr))
      case cns: Expr.Cns => cns
      case Expr.True => Expr.True
    }

    // Pasa por todas las sentencias, remplazando temporales en todas las
    // que tengan expresiones, y a la vez elimina las asignaciones vacías
    rutine.stmts = rutine.stmts flatMap {
      case Stmt.Assign(l, r) if toElim(l) => None
      case Stmt.Assign(l, r) => Some(Stmt.Assign(l, propagate(r)))
      case Stmt.Call(rut, rs) => Some(Stmt.Call(rut, rs map propagate))
      case Stmt.MultiCall(rut, ls, rs) =>
        Some(Stmt.MultiCall(rut, ls, rs map propagate))
      case Stmt.Jmp(lbl, r) => Some(Stmt.Jmp(lbl, propagate(r)))
      case stmt => Some(stmt)
    }

    // Elimina los registros temporales con 1 o 0 usos, si tenían 1,
    // se eliminaron en esta transformación, y si tenían cero ni siquiera
    // se estaban usando en primer lugar
    for (reg <- temps if Uses(reg) <= 2) {
      rutine.vars.set -= reg
    }
  }

  def removeMultiCalls () {
    rutine.stmts = rutine.stmts map {
      case call@Stmt.MultiCall(rut, ls, rs) => ls.size match {
        case 0 => Stmt.Call(rut, rs)
        case 1 => Stmt.Assign(ls(0), Expr.Call(rut, rs))
        case _ => call
      }
      case stmt => stmt
    }
  }

  def collapseLabels () {
    import Stmt._

    val map = mutable.Map[Int, Int]()
    val toElim = mutable.Set[Int]()

    var i = 0
    var prev: Option[Int] = None

    rutine.stmts foreach {
      case Lbl(l) => prev match {
        case Some(n) =>
          map(l) = n
          toElim += l
        case None =>
          map(l) = i
          prev = Some(i)
          i = i+1
      }
      case _ => prev = None
    }

    rutine.stmts = rutine.stmts flatMap {
      case Lbl(l) =>
        if ( toElim(l) ) None
        else Some( Lbl(map(l)) )
      case Jmp(l, a) => Some( Jmp(map(l), a) )
      case stmt => Some(stmt)
    }
  }

  def makeLoops (stmts: Seq[Stmt]): Seq[Stmt] = {
    /*
      A exepcion de break y continue, ningún salto puede salir del bucle, y
      ningún salto externo puede entrar al cuerpo del bucle. Por lo tanto,
      si un bucle empieza antes que otro, también debe terminar después.

      Basandose en esto, se deduce que de varios bucles, el más largo es el
      que termina de último, y si hay varios posibles bucles que empiezan en
      el mismo lugar, el más largo de estos es el bucle final, y el resto de
      saltos son 'continue'.
    */
    import Stmt._

    var reversed = Buffer[Stmt]()
    var i = stmts.size-1

    // Índice del label
    def lblpos (l: Int) = stmts indexWhere {
      case Lbl(`l`) => true
      case _ => false
    }

    // Lista de índices de todos los saltos a este label
    def jmpsTo (l: Int): Seq[Int] = stmts.zipWithIndex flatMap {
      case (Jmp(`l`, cond), i) => Some(i)
      case _ => None
    }

    while (i >= 0) {
      stmts(i) match {
        // Salto hacia atrás
        case Jmp(l, loopCond) if lblpos(l) < i =>
          val start = lblpos(l)
          val end = i

          var block = stmts.slice(start+1, end)

          val valid = block forall {
            case Jmp(l, _) =>
              val i = lblpos(l)
              // (end + 1) por si el label está justo después del final
              // del bucle, en cuyo caso el salto es un break
              (i >= start) && (i <= end+1)

            case Lbl(l) =>
              // No puede (=start) porque start es un lbl, no un jmp
              // tampoco puede (=end) porque end es el propio bucle
              jmpsTo(l) forall {i =>
                (i > start) && (i < end)
              }

            // No se deben capturar
            case _: Break => false
            case _: Continue => false
            // TODO: Deberían poder capturarse y luego convertirse a control
            // de flujo normal, posiblemente con las técnicas de la tesis:
            // "Taming Control Flow"

            case _ => true // Cualquier otro stmt es válido
          }

          if (valid) {
            val startlbl = l
            val endlbl: Option[Int] =
              if (i+1 >= stmts.size) None
              else stmts(i+1) match {
                case Lbl(l) => Some(l)
                case _ => None
              }

            def isEnd (l: Int) = endlbl map (_ == l) getOrElse false

            block = block map {
              case Jmp(`startlbl`, cond) => Continue(cond)
              case Jmp(l, cond) if isEnd(l) => Break(cond)
              case stmt => stmt
            }

            reversed += (loopCond match {
              case Expr.True => block.headOption match {
                case Some(Break(cond)) =>
                  While(
                    Expr.Not(cond),
                    makeLoops(block.tail)
                  )
                case _ => While(Expr.True, makeLoops(block))
              }
              case cond => DoWhile(loopCond, makeLoops(block))
            })
            i = start
          } else {
            reversed += Jmp(l, loopCond)
            i = i-1
          }
        case stmt =>
          reversed += stmt
          i = i-1
      }
    }

    reversed.reverse
  }

  def makeIfs (stmts: Seq[Stmt]): Seq[Stmt] = {
    import Stmt._

    // Índice del label
    def lblpos (l: Int) = stmts indexWhere {
      case Lbl(`l`) => true
      case _ => false
    }

    // Lista de índices de todos los saltos a este label
    def jmpsTo (l: Int): Seq[Int] = stmts.zipWithIndex flatMap {
      case (Jmp(`l`, cond), i) => Some(i)
      case _ => None
    }

    def tryBlock (i: Int, l: Int, cond: Expr): Option[(Int, Stmt)] = {
      val start = i
      val els = lblpos(l)

      if (els <= start) return None

      val (end: Int, body: Seq[Stmt], ebody: Seq[Stmt]) = {
        val bd = stmts.slice(start+1, els)
        bd.lastOption match {
          case Some(Stmt.Jmp(l, cnd)) if lblpos(l) >= els =>
            val end = lblpos(l)
            (end, bd.init, stmts.slice(els+1, end))
          case _ => (els, bd, Nil)
        }
      }

      Some((end, If(
        Expr.Not(cond),
        makeIfs(body),
        makeIfs(ebody)
      )))
    }

    val result = Buffer[Stmt]()

    var i = 0
    while (i < stmts.size) {
      stmts(i) match {
        // Salto hacia adelante
        case Jmp(l, cond) => tryBlock(i, l, cond) match {
          case Some((next, stmt)) =>
            i = next
            result += stmt
          case _ =>
            i = i+1
            result += Jmp(l, cond)
        }
        case While(cond, body) =>
          result += While(cond, makeIfs(body))
          i = i+1
        case DoWhile(cond, body) =>
          result += DoWhile(cond, makeIfs(body))
          i = i+1
        case stmt =>
          i = i+1
          result += stmt
      }
    }

    result
  }

  def cleanUp (stmts: Seq[Stmt]): Seq[Stmt] = {
    import Stmt._

    val lbls = mutable.Set[Int]()

    stmts foreach {
      case Jmp(l, cond) => lbls += l
      case _ =>
    }

    stmts flatMap {
      case Lbl(l) if !lbls(l) => None
      case If(cond, body, ebody) =>
        Some(If(cond, cleanUp(body), cleanUp(ebody)))
      case While(cond, body) =>
        Some(While(cond, cleanUp(body)))
      case DoWhile(cond, body) =>
        Some(DoWhile(cond, cleanUp(body)))
      case stmt => Some(stmt)
    }
  }

  def applyAll () {
    removeMultiCalls()
    propagateVars()
    collapseLabels()
    rutine.stmts = makeLoops(rutine.stmts).toBuffer
    rutine.stmts = makeIfs(rutine.stmts).toBuffer
    rutine.stmts = cleanUp(rutine.stmts).toBuffer
  }
}