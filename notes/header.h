
// Proposed C header for comunicating with Cu

//== Object manipulation ==//

// opaque pointer.
typedef cu_object = void*;

// tagged union
// Esto mide 96 bits!!
typedef cu_any struct {
  enum {
    i8, i16, i32, i64, f32, f64, obj
  } tag;
  union {
    char i8;
    short i16;
    int i32;
    long i64;
    float f32;
    double f64;
    cu_object obj;
  } v;
};

void cu_gcincref (cu_object obj);
void cu_gcdecref (cu_object obj);

//== Module definition ==//

typedef cu_type = void*;

typedef struct {
  int length;
  struct {
    char[] name;
    cu_type type;
  } fields[];
} cu_struct;

void cu_add_module*

cu_typedesc cu_add_struct(cu_module mod, char name[], int fieldc, cu_typedesc fields[]);
void cu_add_function(
  cu_module mod, char name[], void *func(),
  int in_c, int out_c, cu_typedesc params[]
);
