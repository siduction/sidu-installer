#! /bin/bash
# Simulates the installer:
# Waits for 20 seconds and return
# A progress info is written
#set -x
ANSWER=$1
PARAMFILE=$2

mapfile -t <$PARAMFILE LINES
rm $PARAMFILE
PROGRESSFILE=$(echo ${LINES[3]} | sed -e 's/\n//; s/progress=//i;')

function simulation(){
	echo "Progress: '$PROGRESSFILE'"
	
	X=1
	while [[ $X -lt 20 ]]; do
		PROCENT=$(expr $X "*" 5)
		ACTION=${LINES[$X]}
		if [ -z "$ACTION" ] ; then
			ACTION="action $X"
		fi
		echo -e "$PROCENT\t$ACTION" >$PROGRESSFILE
		cat $PROGRESSFILE
		sleep 1
		X=$(expr $X + 1)
	done
	rm $PROGRESSFILE
	touch $ANSWER
}
simulation

