#! /bin/bash
#set -x
DIR=$(pwd)/../tmp/shellserver-tasks
SLEEP=1
VERBOSE=
TRACE_ON=
TRACE_OFF=
CMDDIR=$(pwd)

function oneFile(){
	FN=$1
	mapfile -t <$FN LINES
	rm $FN
	ANSWER=${LINES[0]}
	OPTS=${LINES[1]}
	CMD=${LINES[2]}
	IX=3
	PARAM=
	COUNT=${#LINES[@]}
	while [ $IX -lt $COUNT ] ; do
		if [ -z "${LINES[$IX]}" ] ; then
			# multiple passes kill empty params:
			PARAM="$PARAM ''"
		else
			PARAM="$PARAM ${LINES[$IX]}"
		fi
		IX=$(expr $IX + 1)
	done 
	pushd $CMDDIR >>/dev/null
	if [ "$VERBOSE" == "-v" ] ; then
		echo "$CMD $PARAM -> $ANSWER OPTS: $OPTS"
	fi
	SOURCE=
	FOUND=$(echo $OPTS | grep -i source)
	if [ -n "$FOUND" ] ; then
		SOURCE=source
	fi
	BACKGROUND=
	FOUND=$(echo $OPTS | grep -i background)
	if [ -n "$FOUND" ] ; then
		BACKGROUND="&"
	fi
	 
	case "$CMD" in
	echo)
		echo >$ANSWER $PARAM
		;;
	*)
		SCRIPT=$CMD.sh
		if [ -x $SCRIPT ] ; then
			$TRACE_ON
			CMD="$SOURCE ./$SCRIPT $ANSWER $PARAM"
			if [ -n "$BACKGROUND" ] ; then
				$CMD &
			else
				$CMD
			fi
			$TRACE_OFF
		else
			echo "Unknown command: $CMD File: $ANSWER Param: $PARAM"
		fi
		;;
	esac  
	if [ -f $ANSWER ] ; then 
		chmod uog+rw $ANSWER
	fi 
	popd >/dev/null
}
function poll(){
	FILE=$(echo *.cmd | cut -f 1 -d " ")
	if [ "$FILE" != "*.cmd" ] ; then
		FN=$FILE.active
		mv $FILE $FN
		if [ -f $FN ] ; then
			oneFile $FN
		fi
	fi
}
if [ ! -d $DIR ] ; then
	mkdir $DIR
	chmod uog+rwx $DIR
fi
cd $DIR
if [ "$1" == "-v" ] ; then
	VERBOSE=-v
	TRACE_ON="set -x"
	TRACE_OFF="set +x"
fi
	
while true ; do
	poll
	sleep $SLEEP
done


