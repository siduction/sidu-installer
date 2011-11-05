#! /bin/bash
# This is a server for the sidu-installer
# The tasks are given by files
#
SLEEP=1
export VERBOSE=
export TRACE_ON=
export TRACE_OFF=
TASK_DIR=/var/lib/sidu-installer/shellserver-tasks
ETC_CONFIG=/etc/sidu-installer/shellserver.conf

# Customization
test -e $ETC_CONFIG && source $ETC_CONFIG
test -e $HOME/.shellserverrc && source $HOME/.shellserverrc
export DAEMON=

while [ -n "$1" ] ; do 
	if [ "$1" == "-v" ] ; then
		export VERBOSE=-v
		export TRACE_ON="set -x"
		export TRACE_OFF="set +x"
	elif [ "$1" == "--daemon" ] ; then
		export DAEMON=1
		test -z "$SHELLSERVERLOG" && export SHELLSERVERLOG=/tmp/shellserver.log
	fi
	shift
done
function say(){
	test -n "$SHELLSERVERLOG" && echo $* >>$SHELLSERVERLOG
	test -n "$VERBOSE" && echo $* 
}
SHELLSERVERHOME=$(dirname $0)
test ${SHELLSERVERHOME=:0:1} != '/' && SHELLSERVERHOME=$(pwd)/$SHELLSERVERHOME
test -n "$VERBOSE" && echo "SHELLSERVERHOME=$SHELLSERVERHOME"	

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
		rm -f $FN
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
		say "$CMD $PARAM -> $ANSWER OPTS: $OPTS"
	fi
	pushd $SHELLSERVERHOME >>/dev/null
	
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
			say $CMD
			if [ -n "$BACKGROUND" ] ; then
				if [ -n "$TRACE" ] ; then 
					date "+%H:%M:%S: ===" >>/tmp/shsvtrace.log
					$CMD >>/tmp/shsvtrace.log 2>&1 &
				else
					$CMD &
				fi
			else
				$CMD
			fi
			$TRACE_OFF
		else
			say "Unknown command: $CMD File: $ANSWER Param: $PARAM"
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
	
while true ; do
	poll
	if [ "$1" == -1 -o "$2" == -1 ] ; then
		exit
	fi
	sleep $SLEEP
done


