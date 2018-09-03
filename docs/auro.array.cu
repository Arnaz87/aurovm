
/** The type contained in the array */
extern type `0` as T;

/** The array type. */
type ``;

/** Creates an array of the given length, with all indices initialized with val. */
string new (T val, int length);

/** Gets the value at index */
T get (array, int index);

/** Sets the value at index */
void set (array, int index, T val);
