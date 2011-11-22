#! /bin/bash
ANSWER=$1
CMD=$2
PARAM=$3
TEMP1=$ANSWER.tmp
TEMP2=/tmp/$$.data
set -x
case "$CMD" in
all)
	pushd /usr/share/zoneinfo >/dev/null
	find -maxdepth 2 -type f | grep -v posix | grep -v right | grep -v SystemV \
		| sed 's/^\.\///' | grep -v "/.*/" | grep "/" | sort >$TEMP1
	popd >/dev/null
	mv $TEMP1 $ANSWER
	;;
current)
	cp /etc/timezone $TEMP1
	mv $TEMP1 $ANSWER
	;;
set)
	CITY=$(echo $PARAM | cut -d/ -f2)
	if [ -n $CITY ] ; then
		echo $PARAM >/etc/timezone
	else
		echo "Not a timezone setting: $PARAM"
	fi
	touch $ANSWER
	;;
*)
	echo "Usage: $0 <answer_file> { current | all | set }"
	echo "Cmd: $CMD Args: $0 '$1' '$2'"
	exit 1
	;;
esac
set +x


