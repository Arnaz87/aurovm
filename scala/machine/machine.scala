package arnaud.myvm

class State (_code: Code) {
  //import structures._
  //import Machine._

  val code = _code.code
  val regs = _code.struct.instantiate
  var ret: Key = 0 // Registro en donde guardar el resultado de una función
  var pc: Int = 0 // Program Counter
  var run: Boolean = true

  // Avanzar una instrucción. Los saltos deben establecer esto a false.
  var pcadvance: Boolean = true

  regs(Machine.moduleKey) = _code.module.data

  // Función de utilidad, solo para probar.
  def atlabel (l: String) {
    pc = code.indexOf(code.find{case Instruction.Label(s) => s==l; case _ => false} match {
      case Some(i) => i
      case None => throw new Error(s"Not found label with name $l")
    })
  }

  //def apply(k: Key): Value = regs(k)
  //def update(k: Key, v: Value) = regs(k) = v
  def apply (k: Key) = regs(k)
  def update (k: Key, v: Value) = regs(k) = v

  def check(k: Key, t: Struct) = regs.checkType(k, t)
  def as[T](k: Key): T = apply(k).asInstanceOf[T]
  def checkas[T](k: Key, t: Struct) = {
    regs.checkType(k ,t)
    regs(k).asInstanceOf[T]
  }
}

object Machine {

  //import structures._

  val nullKey: Key = 0 //Addr.Reg("_null")
  val argsKey: Key = 1 //Addr.Reg("_args")
  val returnKey: Key = 2 //Addr.Reg("_return")
  val moduleKey: Key = 3 //Addr.Reg("_module")
  val paramsKey: Key = 4 //Addr.Reg("_params") //?

  val firstKey: Key = 5 // null

  private var debugLevel = 0
  def debug (level: Int) { debugLevel = level }
  def debug (text: String, level: Int) {
    if (level <= debugLevel) {
      println("  " * level + text);
    }
  }
  def debug (text: String) { debug(text, 1) }

  // Estado de la máquina
  val states = new collection.mutable.Stack[State]
  val modules = collection.mutable.Map[String, Module]()

  @scala.annotation.tailrec
  def run () {
    if (!Machine.states.isEmpty) {
      val st = Machine.states.top
      if (st.run) {
        val inst = st.code(st.pc)
        inst.run(st)
        if (st.pcadvance) { st.pc = st.pc + 1 }
        st.pcadvance = true;
      }
      //if (st.run) { exec(st.code(st.pc)) }
      else {
        val result = st(Machine.returnKey)
        val retaddr = st.ret
        Machine.states.pop
        if (retaddr > 0) {
          val st = Machine.states.top
          st(retaddr) = result
        }
      }
      run() // recursive
    }
  }

  def start () {
    Machine.states.push(new State(
      Machine.modules("Main").data.dyn("main").asInstanceOf[Code]
    ))
    run()
  }
}

