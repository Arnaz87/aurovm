
#import <math.h>


// In the Cu header

typedef void* cu_obj;
typedef cu_obj cu_func;
typedef cu_obj cu_type;

typedef struct {
  char[] name;
  cu_type type;
} struct_field;


// End of Cu header

// Revisar "C/Invoke" y "libffi"

// No puede haber una interfaz como lo que trato de hacer...
// Cu puede ser compilado, y una interfaz como esta sería lenta
// Es mejor tener una ffi interna a la máquina y que cada implementación
// se encargue de ver como usarla, obviamente los intérpretes usarían
// libffi o c/invoke, y los compiladores solo compilarían tal cual

void cu_sin (cu_obj args) {
  // uget/uset: unsafe get/set
  // Asume que se sabe exactamente el tipo de dato
  int x;
  cu_uget(args, 1, &x);
  x = sin(x);
  cu_uset(args, 0, &x);
}

void cu_load () {

  cu_func_data sin_func_data = {
    .fields = { // struct_field[]
      {"r", cu_i32},  // # 0
      {"x", cu_i32}   // # 1
    },
    .outs = {"r"},
    .ins = {"x"}
  }

  cu_func sin_func = cu_register_func(cu_func_data);

  struct_field[] struct_data = {
    {"sin", cu_func_value}
  };

  cu_module_data module = {
    .name = "Math",
    .fields = { // c_struct_field[]
      {"sin", cu_func_value}
    },
    .data = { // cu_struct_field[]
      {"sin", sin_func }
    }
  };
  cu_add_module();
}