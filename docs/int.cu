
/** Integer number. Every operation errors on overflow. */

type int;

/* This type is not appropiate for machine interpretations of integers,
    only for natural, human level arithmetic with small numbers,
    and is the most natural for the implementation.
   For integer types appropriate for machine manipulations,
    look for cobre.primitive. */

// These bounds suggest a minimum bit size of 16 bits

/** Maximum possible value for an int. It's value is platform dependent, but it's guaranteed to be greater or equal than  32000. */
int max;

/** Minimum possible value for an int. It's value is platform dependent, but it's guaranteed to be less or equal than -32000. */
int min;


// Arithmetic

/** Returns the negative complement of the number. */
int neg (int);

/** Performs integer addition. */
int add (int, int);

/** Performs integer subtraction. */
int sub (int, int);

/** Performs integer multiplication. */
int mul (int, int);

/** Performs integer division, rounding towards zero. */
int div (int, int);


// Comparisons

/** Tests wether an integer is not zero. */
bool nz (int);

/** Tests wether an integer is greater than zero. */
bool gz (int);

/** Tests wether two integers are equal. */
bool eq (int, int);

/** Tests wether two integers are not equal. */
bool ne (int, int);

/** Tests wether the first integer is greater than the second. */
bool gt (int, int);

/** Tests wether the first integer is greater or equal than the second. */
bool ge (int, int);

/** Tests wether the first integer is less than the second. */
bool lt (int, int);

/** Tests wether the first integer is less or equal than the second. */
bool le (int, int);

