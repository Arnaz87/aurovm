
scalaprojects=bin/bindump bin/cu bin/lua

.PHONY: $(scalaprojects)

$(scalaprojects): bin/%:
	cd scala; sbt $*/package $*/start-script
	echo -e "#!/bin/sh\n$(realpath $<) \$$@" > $@
	chmod +x $@

bin/machine: nim2/*.nim
	nim --checks:on -o:$@ c nim2/main.nim