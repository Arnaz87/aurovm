
scalaprojects=bin/bindump bin/lua

.PHONY: $(scalaprojects) test monitor-test

#$(scalaprojects): bin/%:
#	cd scala; sbt $*/package $*/start-script
#	echo -e "#!/bin/sh\n$(realpath scala/$*/target/start) \$$@" > $@
#	chmod +x $@

bin/cu:
	cd scala; sbt cuJVM/package cuJVM/start-script
	echo -e "#!/bin/sh\n$(realpath scala/cu/jvm/target/start) \$$@" > $@
	chmod +x $@

bin/machine: nim/*.nim
	nim --checks:on -o:$@ c nim/main.nim

bin/nimtest: nim/test.nim nim/parse.nim
	nim --checks:on -o:$@ c nim/test.nim

test: bin/nimtest
	bin/nimtest

monitor-test:
	while inotifywait -q -e close_write nim/; do nim --checks:on -o:bin/nimtest c -r nim/test.nim; done