#! /bin/bash
# Simulates the installer:
# Waits for 20 seconds and return
# A progress info is written
#set -x
ANSWER=$1
PARAMFILE=$2

mapfile -t <$PARAMFILE LINES
PROGRESSFILE=$(echo ${LINES[3]} | sed -e 's/\n//; s/progress=//i;')
CONFIGFILE=$(echo ${LINES[4]} | sed -e 's/\n//; s/configfile=//i;')
rm $PARAMFILE
test -n "$VERBOSE" && echo "Config: $CONFIGFILE"
function simulation(){
	echo "Progress: '$PROGRESSFILE'"
	
	X=1
	while [[ $X -lt 20 ]]; do
		PROCENT=$(expr $X "*" 5)
		ACTION=${LINES[$X]}
		if [ -z "$ACTION" ] ; then
			ACTION="action $X"
		fi
		cat <<EOS >$PROGRESSFILE
PERC=$PROCENT
CURRENT=<b>$ACTION</b>
COMPLETE=completed $X of 20
EOS
		test -n "$VERBOSE" && echo "$PROCENT %"
		sleep 1
		X=$(expr $X + 1)
	done
	rm $PROGRESSFILE
	touch $ANSWER
}
simulation

