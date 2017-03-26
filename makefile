
scalaprojects=bin/bindump bin/cu bin/lua

.PHONY: $(scalaprojects)

$(scalaprojects): bin/%:
	cd scala; sbt $*/package $*/start-script
	echo -e "#!/bin/sh\n$(realpath scala/$*/target/start) \$$@" > $@
	chmod +x $@

bin/machine: nim/*.nim
	nim --checks:on -o:$@ c nim/main.nim