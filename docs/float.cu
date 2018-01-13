
/** Floating pofloat number. */

type float;


// Arithmetic

/** Returns the negative complement of the number. */
float neg (float);

/** Performs float addition. */
float add (float, float);

/** Performs float subtraction. */
float sub (float, float);

/** Performs float multiplication. */
float mul (float, float);

/** Performs float division, rounding towards zero. */
float div (float, float);


// Comparisons

/** Tests wether an float is not zero. */
bool nz (float);

/** Tests wether an float is greater than zero. */
bool gz (float);

/** Tests wether two floats are equal. */
bool eq (float, float);

/** Tests wether two floats are not equal. */
bool ne (float, float);

/** Tests wether the first float is greater than the second. */
bool gt (float, float);

/** Tests wether the first float is greater or equal than the second. */
bool ge (float, float);

/** Tests wether the first float is less than the second. */
bool lt (float, float);

/** Tests wether the first float is less or equal than the second. */
bool le (float, float);

