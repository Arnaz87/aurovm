
/**< Add hoc utility module for working with the system */

/** File handle */
type file;

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

/** Opens a file in the given mode */
file open (string path, string mode);

/** Reads all the contents of a file to string */
string readall (string path);

/** Writes a string to a file*/
void write (file, string);

/** Writes a single byte to a file */
void writebyte (file, int);
