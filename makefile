
PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin

scalaprojects=bin/bindump bin/lua

.PHONY: $(scalaprojects) test jstest monitor-test

#$(scalaprojects): bin/%:
#	cd scala; sbt $*/package $*/start-script
#	echo -e "#!/bin/sh\n$(realpath scala/$*/target/start) \$$@" > $@
#	chmod +x $@

bin/cu:
	cd scala; sbt cuJVM/package cuJVM/start-script
	echo -e "#!/bin/sh\n$(realpath scala/cu/jvm/target/start) \$$@" > $@
	chmod +x $@

bin/cobre: nim/*.nim
	nim --checks:on -o:$@ c nim/main.nim

bin/cobre-release: nim/*.nim
	nim -d:release -o:$@ c nim/main.nim

bin/nimtest: nim/*.nim
	nim --checks:on -o:$@ -d:test c nim/test.nim

bin/nimtest.js: nim/*.nim
	nim js -d:nodejs -d:test --checks:on -o:$@ nim/test.nim

test: bin/nimtest
	bin/nimtest

jstest: bin/nimtest.js
	node bin/nimtest.js

monitor-test:
	while inotifywait -q -e close_write nim/; do make test; done

install: bin/cobre
	install bin/cobre $(BINDIR)/cobre5

uninstall:
	rm -f $(BINDIR)/cobre5
