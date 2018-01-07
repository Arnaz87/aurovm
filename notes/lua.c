
// In the Cu header

typedef cu_obj void*;

// End of Cu header
#define HASH_TABLE_SIZE 500

typedef LuaObj struct {
  int arraySize;
  cu_obj[] array;
  cu_hashtable hash_table*;
};

void lua_get () {
  
}