
import cobre.system { void print (string); }

import module argument {
  type `0` as X;
  // If this line is included, test.cu doesn't typecheck. That's intended.
  //void `1` () as f;
}

type T (X);

T make (X x) { return x as T; }
X get (T t) { return t as X; }