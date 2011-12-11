#! /bin/bash
ANSWER=$1
CMD=$2
ARG=$3

#RUN="echo simulating" 
TEMP1=$ANSWER.tmp
set -x
INPUT=fw-test.txt
test -f $INPUT || INPUT=""
case "$CMD" in
info)
	perl firmware.pl $INPUT >$TEMP1
	mv $TEMP1 $ANSWER
	;;
install)
	CONFIG=/etc/apt/sources.list.d/debian.list
	if ! grep ^deb.*non-free/ $CONFIG ; then
		sed -i -e 's/main/main non-free/;' $CONFIG
	fi 	
	date "+%Y.%m.%d-%H:%M:%S Installing firmware..." >$TEMP1
	while [ -n "$ARG" ] ; do
		ITEM=${ARG%%;*}
		ARG=${ARG#*;}
		test "$ARG" = "$ITEM" && ARG=
		test -n "$ITEM" && $RUN fw-detect -i $ITEM >>$TEMP1 2>&1
	done
	if [ -f $TEMP1 ] ; then
		mv $TEMP1 $ANSWER
	else
		touch $ANSWER
	fi
	LINK=../public/firmware_log.txt
	test -L $LINK && rm $LINK
	ln -s $ANSWER $LINK
	;;
*)
	echo "unknown command: $CMD" | tee $ANSWER
	;;
esac
set +x
chmod uog+rw $ANSWER