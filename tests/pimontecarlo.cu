
import cobre.system;
import cobre.float;
import cobre.string;

float, int rand(int st) {
	st = st * 4005 + 165;
	while (st >= 65536) {
		st = st - 65536;
	}
	return itof(st / 65536.0), st;
}

void main () {
	int st = 1234;
	int count = 10000;
	int inside = 0;
	int i = 0;

	float start = clock();
	while (i < count) {
		float x, y;
		x, st = rand(st);
		y, st = rand(st);
		if (x*x + y*y <= 1.0) {
			inside = inside+1;
		}
		i = i+1;
	}
	float fin = clock();
	float time = fin - start;

	float pi = itof((inside/count)*4);
	print("PI: " + ftos(pi) + " in " + ftos(time) + "s");
}
