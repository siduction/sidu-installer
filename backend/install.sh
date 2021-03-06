#! /bin/bash
# Simulates the installer:
# Waits for 20 seconds and return
# A progress info is written
#set -x
ANSWER=$1
ANSWER_TEMP=$ANSWER.tmp
PARAMFILE=$2
ETC_CONFIG=/etc/sidu-installer/shellserver.conf

test -e $ETC_CONFIG && source $ETC_CONFIG

mapfile -t <$PARAMFILE LINES
PROGRESSFILE=$(echo ${LINES[3]} | sed -e 's/\n//; s/progress=//i;')
CONFIGFILE=$(echo ${LINES[4]} | sed -e 's/\n//; s/configfile=//i;')
rm -f $PARAMFILE


if [ -n "$DUMMY_INSTALL" ] ; then
	NO=1
	while [ $NO != 11 ] ; do
		echo === Dummy Installation Answer $NO: $ANSWER Progress: $PROGRESSFILE
		sleep 10
		cat <<EOS >$PROGRESSFILE
PERC=0.${NO}0
CURRENT=<b>Part $NO</b>
COMPLETE=completed $NO of 10
EOS
	        NO=$(expr $NO + 1)
	done
	echo "Fertig!" >$ANSWER
	echo === Dummy Installation ready
	exit 0
fi	
test -n "$VERBOSE" && echo "Config: $CONFIGFILE"
# fll-installer:progress.pm needs a non empty DISPLAY
test -n "$DISPLAY" || export DISPLAY=:0

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
	rm -f $PROGRESSFILE
	touch $ANSWER
}

function fll_install(){
	CONFIG=$HOME/.sidconf
	mv $CONFIGFILE $CONFIG
	grep CRYPT= $CONFIG
	./automount-control.sh disabled
	pushd $FLL_SEARCHPATH
	test -n "$VERBOSE" && echo "progress: $PROGRESSFILE FLL_SEARCHPATH=$FLL_SEARCHPATH"
	test -n "$SHELLSERSVERLOG" && echo >>$SHELLSERSVERLOG "progress: $PROGRESSFILE FLL_SEARCHPATH=$FLL_SEARCHPATH"
	cat <<EOS >$PROGRESSFILE
PERC=1
CURRENT=<b>Initialization</b>
COMPLETE=completed 0 of 10
EOS
	CMD=$(which fll-installer)
	test -z "$CMD" && test -e fll-installer && CMD=./fll-installer
	test -z "$CMD" && CMD=$BIN_FLL_INSTALLER
	test -n "$SHELLSERVERLOG" && echo >> $SHELLSERVERLOG "pwd=$(pwd) ; ./fll-installer -i $PROGRESSFILE"
	$CMD -i $PROGRESSFILE >$ANSWER_TEMP 2>&1
	mv $ANSWER_TEMP $ANSWER
	test -n "$VERBOSE" && ls -ld $ANSWER
	rm -f $PROGRESSFILE
	test -n "$VERBOSE" && echo $PROGRESSFILE was removed
	popd >/dev/null 2>&1
	./automount-control.sh enabled
}

fll_install

