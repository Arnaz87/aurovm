package arnaud.culang
import scala.collection.mutable.ArrayBuffer
import arnaud.myvm.codegen.{Nodes => CG, Node => CGNode}

object CodeGen {
  def gen (node: Ast.Node): CGNode = {
    import Ast._
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

      /*case Import(mod, fs) =>
        CG.Block(fs map {case ImportField(Id(nm), imp) =>
          CG.TypeSet(nm, CG.Import(mod, imp))
        })*/
      case Import(mod, fs) => CG.Nil
      case Proc(Id(procnm), params, body) =>
        CG.Proc(procnm, Nil, // returns
          params map {case Param(tp, Id(nm)) => nm},
          gen(body)
        )
    }
  }

  def program (prg: Ast.Program): CGNode = CG.Block(prg.stmts map (gen _))
}