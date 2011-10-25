#! /bin/bash
#set -x
ARGS=$*

SLEEP=1
export VERBOSE=
export TRACE_ON=
export TRACE_OFF=
TASK_DIR=/var/lib/sidu-installer/shellserver-tasks
ETC_CONFIG=/etc/sidu-installer/install.conf


CMDDIR=$(pwd)
# Customization
test -e $ETC_CONFIG && source $ETC_CONFIG
test -e $HOME/.shellserverrc && source $HOME/.shellserverrc

function oneFile(){
	FN=$1
	mapfile -t <$FN LINES
	ANSWER=${LINES[0]}
	OPTS=${LINES[1]}
	CMD=${LINES[2]}
	REQUSTFILE=
	FOUND=$(echo $OPTS | grep -i requestfile)
	if [ -n "$FOUND" ] ; then
		PARAM=$(pwd)/$FN.IN_WORK
		mv $FN $PARAM
		FN=$PARAM
	else
		rm $FN
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
		if [ "$VERBOSE" == "-v" ] ; then
			echo "$CMD $PARAM -> $ANSWER OPTS: $OPTS"
		fi
	fi
	pushd $CMDDIR >>/dev/null
	
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
if [ ! -d $TASK_DIR ] ; then
	mkdir -p $TASK_DIR
	chmod uog+rwx $TASK_DIR
	NODE=$(basename $(dirname $TASK_DIR))
	test $NODE == 'sidu-installer' && chmod uog+rwx $TASK_DIR/../../$NODE
fi
cd $TASK_DIR
if [ "$1" == "-v" ] ; then
	export VERBOSE=-v
	export TRACE_ON="set -x"
	export TRACE_OFF="set +x"
fi
	
while true ; do
	poll
	if [ "$1" == -1 -o "$2" == -1 ] ; then
		exit
	fi
	sleep $SLEEP
done


