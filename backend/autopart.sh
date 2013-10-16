#! /bin/bash
test -n "$VERBOSE" && set -x
ANSWER=$1
CMD=$2
PROGRESS=$3
DISKINFO=$4
ALLOW_INIT=$5
PARTS=$6
VG_INFO=$7
LV_INFO=$8
MAX_SIZE=$9
CODE=$10
FULL_LOG=../public/autopart_log.txt

if [ -z "$VERBOSE" ] ; then
	perl autopart.pl "$CMD" "$ANSWER" "$PROGRESS" "$DISKINFO" "$ALLOW_INIT" \
		"$PARTS" "$VG_INFO" "$LV_INFO" "$MAX_SIZE" "$CODE" > $FULL_LOG 2>&1
else 
	perl autopart.pl "$CMD" "$ANSWER" "$PROGRESS" "$DISKINFO" "$ALLOW_INIT" \
		"$PARTS" "$VG_INFO" "$LV_INFO" "$MAX_SIZE" "$CODE" 2>&1 | tee $FULL_LOG 
fi
test -n "$VERBOSE" && cat "$ANSWER"
test -n "$VERBOSE" && ls -ld $FULL_LOG
test -n "$VERBOSE" && echo "=================================================="
