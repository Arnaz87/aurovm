
/** Floating pofloat number. */

type float;

// The numbers representable by this type must be at least of 4 digits of
// decimal precision from 0.001 to 1000, that is, it must be able to represent
// 0, 0.001, 0.002, 0.003 ... 10.01 ... 100.1 ... 998, 999, 1000
// This suggest floating point with 10 mantissa and 2 exponent bits,
// or a fixed point with 10 bits on both sides (plus sign for both)

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

/** Tests wether two floats are equal. Algebraic identities might not hold after float calculations. */
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


// Creation

/** Converts an int to a float. */
float itof (int);

/** Converts a float to an int. */
int ftoi (float);

/** Creates a float given a magnitude and an exponent base 10 */
float decimal (int magnitude, int exponent);

float nan ();
float inf ();
bool isnan (float);
bool isinf (float);
