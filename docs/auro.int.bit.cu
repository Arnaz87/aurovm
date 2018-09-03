
// Operations on integers as if they were in 16 bit 2-complement binary representation

int not (int);

int and (int, int);
int or (int, int);
int xor (int, int);
int eq (int, int);

// bitshift can only shift positive 16 bit numbers, otherwise is an error
// if left shifting overflows the 16 bits is an error
int shl (int, int);
int shr (int, int);