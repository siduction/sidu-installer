#! /bin/bash
ANSWER=$1
PROGRESS=$2

test -n "$VERBOSE" && echo === answer: $ANSWER progress: $PROGRESS 
perl partinfo.pl "$ANSWER" "$PROGRESS"
if [ -n "$VERBOSE" ] ; then
	cat $ANSWER
fi
test -n "$VERBOSE" && ls -l $ANSWER
