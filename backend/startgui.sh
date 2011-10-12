#! /bin/bash
ANSWER=$1
APPL=$2
ARGS=$3
USER=$4
OPTS=$5
ARGS=$(echo $ARGS | sed -e "s/''//g")
CONSOLE=
if [ -z "$DISPLAY" ] ; then
	export DISPLAY=:0
fi
FOUND=$(echo $OPTS | grep -i console)
if [ -n "$FOUND" ] ; then
	sux $USER konsole -e $APPL $ARGS
	AGAIN=1
	while [ -n "$AGAIN" ] ; do
		set -x
		AGAIN=$(ps aux | grep $APPL | grep -v grep | grep -v $0)
		set +x
		sleep 1
	done
else
	sux $USER $CONSOLE $APPL $ARGS
fi
echo $? >$ANSWER
chmod uog+w $ANSWER
echo $ANSWER ready!
