#! /bin/bash
test -n "$VERBOSE" && set -x
ANSWER=$1
CMD=$2
DISKINFO=$3
ALLOW_INIT=$4
PARTS=$5
VG_INFO=$6
LV_INFO=$7
PROGRESS=$8
FULL_LOG=../public/autopart_log.txt

if [ -z "$VERBOSE" ] ; then
	perl autopart.pl "$CMD" "$ANSWER" "$DISKINFO" "$ALLOW_INIT" "$PARTS" \
		"$VG_INFO" "$LV_INFO" "$PROGRESS" > $FULL_LOG 2>&1
else 
	perl autopart.pl "$CMD" "$ANSWER" "$DISKINFO" "$ALLOW_INIT" "$PARTS" \
		"$VG_INFO" "$LV_INFO" "$PROGRESS" 2>&1 | tee $FULL_LOG 
fi
test -n "$VERBOSE" && cat "$ANSWER"
test -n "$VERBOSE" && ls -ld $FULL_LOG
test -n "$VERBOSE" && echo "=================================================="
