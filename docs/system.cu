
/**< Add hoc utility module for working with the system */

/** Prints a line to standard output */
void print (string);

/** Reads a line from standard input */
string read ();

/** Executes a command in the OS shell and returns its output */
string cmd (string);

/** Executes a command in the OS shell and returns its error code */
int exec (string);

/** Returns the time spent by the process in seconds */
float clock ();

/** Reads the contents of a file into a byte array */
byte[] readfile (string filename);

/** Writes a byte array into a file */
void writefile (string filename, byte[] content);
