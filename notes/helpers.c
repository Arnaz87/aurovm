

/*

Esto no es una interfaz para interactuar con la máquina o introducir funciones
nativas, es un api para crear programas definidos completamente con semánticas
de Cobre.

En vez de tener un formato de serialización estándar, tendré un api simple de
funciones para crear programas, el formato entonces estaría definido en
términos de este api. Cada implementación entonces debe implementar el api,
en cualquier lenguaje y para cualquier backend, el cargador del formato, que
incluiría el parser y todo eso, es opcional y es decisión del implementador
si incluirlo o no.

*/

#include "cobre.h"
{
  // Todos los tipos son opacos, no necesariamente punteros opacos, pero
  // lo que sea. Nunca deben usarse directamente.

  cu_module cu_module_reference(char *name);
  cu_type cu_type_reference(cu_module module, char *name);
  cu_function cu_function_reference(
    cu_module module, char *name, int params_in, int params_out);

}

cu_module prelude = cu_module_reference("Prelude");
cu_type cu_num = cu_type_reference(prelude, "Number");
cu_type cu_bool = cu_type_reference(prelude, "Boolean");
cu_function cu_lt = cu_function_reference(prelude, "lt", 2, 1);
cu_function cu_gt = cu_function_reference(prelude, "gt", 2, 1);

cu_module module = new_cu_module();

cu_function clamp = cu_new_function(module, "clamp");

cu_reg t_reg = cu_add_register(clamp, "t", cu_num);
cu_reg a_reg = cu_add_register(clamp, "a", cu_num);
cu_reg b_reg = cu_add_register(clamp, "b", cu_num);
cu_reg r_reg = cu_add_register(clamp, "r", cu_num);
cu_reg lta_reg = cu_add_register(clamp, "lta", cu_bool);
cu_reg ltb_reg = cu_add_register(clamp, "gtb", cu_bool);

cu_add_in_param(clamp, t_reg);
cu_add_in_param(clamp, a_reg);
cu_add_in_param(clamp, b_reg);
cu_add_out_param(clamp, r_reg);

cu_instruction inst;

// Invocación de función
  // Version 1
  inst = new_cu_call_instruction(cu_lt, [t_reg, a_reg], [lta_reg]);
  cu_add_instruction(clamp, inst);

  // Version 2
  inst = cu_add_instruction(clamp, cu_call_instruction);
  cu_add_inst_in_param(inst, t_reg);
  cu_add_inst_in_param(inst, a_reg);
  cu_add_inst_out_param(inst, lta_reg);

  // Version 3
  cu_call_instruction call = new_cu_call_instruction();
  cu_add_inst_in_param(call, t_reg);
  cu_add_inst_in_param(call, a_reg);
  cu_add_inst_out_param(call, lta_reg);
  inst = cu_add_instruction(clamp, call);

  // Version 4
  inst = cu_call_instruction(clamp);

// Salto condicional
  // Version 1
  // ???
  
  // Version 2
  inst = cu_add_instruction(clamp, cu_if_instruction);
  cu_add_inst_in_param(inst, lta_reg);
  // Llamar luego
  //cu_add_jump_target(inst, $inst);

  // Version 3
  cu_call_if iif = new_cu_if_instruction();
  cu_add_inst_if_param(iif, )
  //cu_add_inst_jump_target(call, $inst);
