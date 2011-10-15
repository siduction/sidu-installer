#! /bin/bash
ANSWER=$1
CMD=$2
TEMP1=$ANSWER.tmp
TEMP2=/tmp/$$.data
if [ "$CMD" == "all" ] ; then
	pushd /usr/share/zoneinfo >/dev/null
	find -maxdepth 2 -type f | grep -v posix | grep -v right | grep -v SystemV \
		| sed 's/^\.\///' | grep -v "/.*/" | grep "/" | sort >$TEMP1
	popd >/dev/null
	mv $TEMP1 $ANSWER
elif [ "$CMD" == "current" ] ; then
	cp /etc/timezone $TEMP1
	mv $TEMP1 $ANSWER
else
	echo "Usage: $0 <answer_file> { current | all }"
	echo "$0 '$1' '$2'"
	exit 1
fi



