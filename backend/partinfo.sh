#! /bin/bash
ANSWER=$1
PROGRESS=$2
TEMP1=$ANSWER.tmp
test -n "$VERBOSE" && echo === answer: $ANSWER progress: $PROGRESS 
if [ -z "$VERBOSE" ] ; then
	perl partinfo.pl "$PROGRESS" >$TEMP1
else 
	perl partinfo.pl "$PROGRESS" | tee $TEMP1
fi

test -n "$VERBOSE" && ls -l $ANSWER
mv $TEMP1 $ANSWER
