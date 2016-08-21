package arnaud.myvm

abstract sealed class Instruction {
  def run (st: State) {
    val clname = this.getClass.getName
    throw new scala.NotImplementedError("Instrucción sin implementación: " + clname)
  }
}

/* Sintaxis alternativa

case class Instruction (f: State => Unit)
def Mov (a: Key, b: Key) = Instruction(st => st(a) = st(b))

Es mucho más corto definir las instrucciones así, pero tiene algunos detalles.
Se basa en funciones anónimas con closuras, que es un poco más pesado que
objetos con atributos y métodos.
Es imposible saber de qué método salió la instrucción, así que no se pueden
identificar. Por ahora no lo hago, pero es algo demasiado útil.
*/

object Instruction {
  type Inst = Instruction

  case class Mov (a: Key, b: Key) extends Inst {
    override def run (st: State) { st(a) = st(b) }
  }
  case class Neg (a: Key) extends Inst {
    override def run (st: State) { st(a) = 0 - st.as[Double](a) }
  }
  case class Inc (a: Key) extends Inst {
    override def run (st: State) { st(a) = st.as[Double](a) + 1 }
  }
  case class Dec (a: Key) extends Inst {
    override def run (st: State) { st(a) = st.as[Double](a) - 1 }
  }

  case class Add (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) + st.as[Double](c)
    }
  }
  case class Sub (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) - st.as[Double](c)
    }
  }
  case class Mul (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) * st.as[Double](c)
    }
  }
  case class Div (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) / st.as[Double](c)
    }
  }
  case class Pow (a: Key, b: Key, c: Key) extends Inst //?
  case class Mod (a: Key, b: Key, c: Key) extends Inst //?

  case class Gtz (a: Key, b: Key) extends Inst {
    override def run (st: State) { st(a) = st.as[Double](b) > 0 }
  }
  case class Eq  (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as(b) == st.as(c)
    }
  }
  case class Neq (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as(b) != st.as(c)
    }
  }
  case class Lt  (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) < st.as[Double](c)
    }
  }
  case class Lte (a: Key, b: Key, c: Key) extends Inst {
    override def run (st: State) {
      st(a) = st.as[Double](b) <= st.as[Double](c)
    }
  }

  case class Jmp (i: Int) extends Inst {
    override def run (st: State) { st.pc = i; st.pcadvance = false }
  }
  case class If  (i: Int, a: Key) extends Inst {
    override def run (st: State) {
      if (st.as[Boolean](a)) { st.pc = i; st.pcadvance = false }
    }
  }
  case class Ifn (i: Int, a: Key) extends Inst {
    override def run (st: State) {
      if (!st.as[Boolean](a)) { st.pc = i; st.pcadvance = false }
    }
  }

  case class Nobj (a: Key) extends Inst //?
  case class Get (a: Key, b: Key, k: Key) extends Inst {
    override def run (st: State) {
      st(a) = st(b) match {
        case obj:Object => obj(k)
        case _ => throw new Exception("Cannot access a not object")
      }
    }
  }
  case class Set (a: Key, k: Key, v: Key) extends Inst {
    override def run (st: State) {
      st(a) match {
        case obj:Object => obj(k) = st(v)
        case _ => throw new Exception("Cannot access a not object")
      }
    }
  }

  case class Load (a: Key, m: String, n: String) extends Inst {
    override def run (st: State) { st(a) = Machine.modules(m).data.dyn(n) }
  }
  case class Call (a: Key, fun: Key, args: Key) extends Inst {
    override def run (st: State) { 
      st(fun) match {
        case Runnable(f) =>
          Machine.debug(":: Running Native")
          st(a) = f(st(args))
        case f: Code =>
          Machine.debug(":: Calling Code")
          val nst = new State(f)
          nst.ret = a
          nst(Machine.argsKey) = st(args)
          Machine.states.push(nst)
      }
    }
  }
  case object End extends Inst {
    override def run (st: State) { st.run = false; st.pcadvance = false }
  }

  case class Cast (a: Key, b: Key, t: Struct) extends Inst {
    override def run (st: State) { }
  }


  case class DynObj (a: Key) extends Inst {
    override def run (st: State) { st(a) = new Dict() }
  }
  case class DynGet (a: Key, b: Key, k: String) extends Inst {
    override def run (st: State) {
      st(a) = st(b) match {
        case obj: Dict => obj(k)
        case obj: Object => obj.dyn(k)
      }
    }
  }
  case class DynSet (a: Key, k: String, v: Key) extends Inst {
    override def run (st: State) {
      st(a) match {
        case obj: Dict => obj(k) = st(v)
        case obj: Object => obj.dyn(k) = st(v)
      }
    }
  }

  // Solo para probar
  case class Const (a: Key, k: String) extends Inst
  case class Copy  (k: Key, v: Value) extends Inst {
    override def run (st: State) { st(k) = v }
  }
  case class Print (a: Key) extends Inst {
    override def run (st: State) { println(st(a)) }
  }
  case class Label (name: String) extends Inst
  case class Native (f: () => Unit) extends Inst
}