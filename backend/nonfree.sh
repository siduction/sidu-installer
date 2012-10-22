#! /bin/bash
ANSWER=$1
CMD=$2
set -x
TEMP1=$ANSWER.tmp
test -f "$TEMP1" && rm $TEMP1
CONFIG=/etc/apt/sources.list.d/debian.list

case "$CMD" in
info)
	grep "^deb.*non-free" $CONFIG >$TEMP1
	;;
install)
	CONFIG=/etc/apt/sources.list.d/debian.list
	if ! grep "^deb.*non-free" $CONFIG >/dev/null ; then
		sed -i -e 's/main/main non-free/;' $CONFIG
	fi 	
	if ! grep "^deb.*contrib" $CONFIG >/dev/null ; then
		sed -i -e 's/main/main contrib/;' $CONFIG
	fi
	touch $TEMP1
	;;
*)
	echo "unknown command: $CMD" | tee $TEMP1
	;;
esac
mv $TEMP1 $ANSWER
