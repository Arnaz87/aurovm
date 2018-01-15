
/** Immutable string type. Positions are byte based, not character based. All operations are nondestructive. */
type string;

/** Unicode character type. One character may span many positions in a string. */
type char;


// Creation

/** Creates a string from binary data */
string new (bin);

/** Returns the character mathing the given code point */
char fromcode (int);

/** Gives the string representation of an int */
string itos(int);

/** Gives the string representation of a float */
string ftos(float);


// Manipulation

/** Adds a character to the end of the string */
string add (string, char);

/** Concatenates two strings */
string concat (string, string);

/** Returns a string starting from the character at start, until and not including the character at end */
string slice (string, int start, int end);


// Retrieval

/** Compares the strings content */
bool eq (string, string);

/** Given a string and a position, returns the character at that position and the position of the next character */
char, int charat (string, int);

/** Returns the code point of the given character */
int codeof (char);

/** Returns the size in bytes of the string */
int len (string);
