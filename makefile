
scalaprojects=bin/bindump bin/cu bin/lua

scala/%/target/start: scala/%/*.scala scala/*.sbt
	cd scala; sbt $*/package $*/start-script

$(scalaprojects): bin/%: scala/%/target/start
	echo -e "#!/bin/sh\n$(realpath $<) \$$@" > $@
	chmod +x $@

bin/machine: nim2/*.nim
	nim --checks:on -o:$@ c nim2/main.nim