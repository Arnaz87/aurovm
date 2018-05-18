
import cobre.system { void print (string); }

import module argument {
  type `0` as X;
  void `1` () as f;
}

type T (X);

T make (X x) { return x as T; }
X get (T t) { return t as X; }