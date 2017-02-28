package arnaud.culang
import scala.collection.mutable.{ArrayBuffer, Map}
import arnaud.myvm.codegen.{Nodes => CG, Node => CGNode}

sealed abstract class NameUse
case object TypeUse extends NameUse
case object ProcUse extends NameUse

class CodeGen {
  import Ast._

  val uses: Map[String, NameUse] = Map()

  def genSyms (node: Ast.Node) {
    node match {
      case Call(Id(fnm), args) =>
        uses(fnm) = ProcUse
        args foreach genSyms
      case Assign(_, vl) => genSyms(vl)
      case While(cond, body) =>
        genSyms(cond)
        genSyms(body)
      case If(cond, body, orelse) =>
        genSyms(cond)
        genSyms(body)
        orelse foreach genSyms
      case Block(stmts) => stmts foreach genSyms
      case Proc(Id(procnm), params, results, body) =>
        uses(procnm) = ProcUse
        genSyms(body)
      case _ =>
    }
  }

  def gen (node: Ast.Node): CGNode = {
    node match {
      case Num(n) => CG.Num(n)
      case Str(s) => CG.Str(s)
      case Bool(b) => CG.Bool(b)
      case Null => CG.Nil
      case Var(Id(name)) => CG.Var(name)

      case Call(Id(fnm), args) => CG.Call(fnm, args map gen)

      case Decl(tp, pts) => {
        CG.Block(pts.map {
          case DeclPart(Id(nm), None) => List(CG.Declare(nm))
          case DeclPart(Id(nm), Some(expr)) =>
            List(CG.Declare(nm), CG.Assign(nm, gen(expr)))
        }.flatten)
      }
      case Assign(Id(nm), vl) => CG.Assign(nm, gen(vl))
      case Block(xs) => CG.Scope(CG.Block(xs.map(gen _)))
      case While(cond, body) => CG.While(gen(cond), gen(body))
      case If(cond, block, orelse) =>
        CG.If(gen(cond), gen(block), orelse match {
          case Some(eblock) => gen(eblock)
          case None => CG.Nil
        })

      case Import(mod, nm) =>
        uses get nm match {
          case Some(ProcUse) => CG.ImportProc(nm, mod, nm)
          case Some(TypeUse) => CG.ImportProc(nm, mod, nm)
          case None => CG.Nil
        }
      case Proc(Id(procnm), params, results, body) =>
        CG.Proc(procnm,
          results.zipWithIndex map {
            case (Type(nm), i) => s"$$ret_$i"
          },
          params map {case Param(tp, Id(nm)) => nm},
          gen(body)
        )
      case Return(xs) =>
        CG.Block(xs.zipWithIndex.map{
          x:(Expr,Int) => x match {
            case (expr, i) => CG.Assign(s"$$ret_$i", gen(expr))
          }
        } :+ CG.Return)
    }
  }
}

object CodeGen {
  def program (prg: Ast.Program): CGNode = {
    val codegen = new CodeGen
    prg.stmts foreach codegen.genSyms
    CG.Block(prg.stmts map (codegen.gen _))
  }
}