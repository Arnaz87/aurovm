
PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
SRC = src/*.nim src/*/*.nim

bin/cobre: $(SRC)
	nim --checks:on -o:$@ c src/main.nim

bin/cobre-release: $(SRC)
	nim -d:release -o:$@ c src/main.nim

bin/nimtest: $(SRC)
	nim --checks:on -o:$@ -d:test c src/test.nim

bin/nimtest.js: $(SRC)
	nim js -d:nodejs -d:test --checks:on -o:$@ src/test.nim

test: bin/nimtest
	bin/nimtest

jstest: bin/nimtest.js
	node bin/nimtest.js

monitor-test:
	while inotifywait -q -e close_write src/; do make test; done

install: bin/cobre
	install bin/cobre $(BINDIR)/cobre

uninstall:
	rm -f $(BINDIR)/cobre
