#! /bin/bash
ANSWER=$1
CMD=$2
ARG=$3

#RUN="echo simulating" 
TEMP1=$ANSWER.tmp

test -f "$TEMP1" && rm $TEMP1
INPUT=fw-test.txt
test -f $INPUT || INPUT=""
case "$CMD" in
info)
	FN=/tmp/fw-update.done
	if [ ! -f $FN ] ; then
		$RUN apt-get update
		touch $FN
	fi
	perl firmware.pl $INPUT >$TEMP1
	cp $TEMP1 /tmp/last.info
	mv $TEMP1 $ANSWER
	;;
install)
	CONFIG=/etc/apt/sources.list.d/debian.list
	CONFIG2=/etc/apt/sources.list.d/siduction.list
	UPDATE=0
	if ! grep "^deb.*non-free" $CONFIG >/dev/null ; then
		sed -i -e 's/main/main non-free/;' $CONFIG
		UPDATE=1
	fi 	
	if ! grep "^deb.*contrib" $CONFIG >/dev/null ; then
		sed -i -e 's/main/main contrib/;' $CONFIG
		UPDATE=1
	fi 	
	if ! grep "^deb.*/fixes.*non-free" $CONFIG2 >/dev/null ; then
		sed -i -e 's/^\(deb.*[/]fixes.*main\)/\1 non-free/;' $CONFIG2
		UPDATE=1
	fi 	
	if ! grep "^deb.*/fixes.*contrib" $CONFIG2 >/dev/null ; then
		sed -i -e 's/^\(deb.*[/]fixes.*main\)/\1 contrib/;' $CONFIG2
		UPDATE=1
	fi
	date "+%Y.%m.%d-%H:%M:%S Installing firmware..." >$TEMP1
	if [ 1 = 1 -o $UPDATE ] ; then
		echo "apt-get update" >>$TEMP1
		apt-get update | tail -n 5 >>$TEMP1
	fi
	while [ -n "$ARG" ] ; do
		ITEM=${ARG%%;*}
		if [ "$ITEM" = "$ARG" ] ; then
			ARG=
		else
			ARG=${ARG#*;}
		fi
		if [ -n "$ITEM" ] ; then
		    CMDLIST=${ITEM#*|}
		    if [ "$CMDLIST" = "$ITEM" ] ; then
		    	MODULE="$ITEM"
		    	CMDLIST=
		    else
		    	MODULE="${ITEM%%|*}"
		    fi
			if [ "$MODULE" = "amd64-microcode" -o "$MODULE" = "intel-microcode" ] ; then
				$RUN apt-get install $MODULE >>$TEMP1 2>&1
			elif [ "$MODULE" = "-all" ] ; then
				echo "fw-detect -vvv -y" >>$TEMP1
				$RUN fw-detect -vvv -y >>$TEMP1 2>&1
			else
				echo "fw-detect -vvv -i $MODULE" >>$TEMP1 
				$RUN fw-detect -i $MODULE >>$TEMP1 2>&1
			fi
			while [ -n "$CMDLIST" ] ; do
				SUBCMD=${CMDLIST%%|*}
				if [ "$SUBCMD" = "$CMDLIST" ] ; then
					CMDLIST=
				else
					CMDLIST=${CMDLIST#*|}
				fi
				SUBCMD="$(echo $SUBCMD | sed 's/~/ /g')"
				echo "$SUBCMD" >>$TEMP1
				$RUN $SUBCMD >>$TEMP1 2>&1
			done
		fi
	done
	if [ -f $TEMP1 ] ; then
		cp $TEMP1 /tmp/last.answer
		mv $TEMP1 $ANSWER
	else
		touch $ANSWER
	fi
	LINK=../public/firmware_log.txt
	test -L $LINK && rm $LINK
	ln -s $ANSWER $LINK
	;;
*)
	echo "unknown command: $CMD" | tee $ANSWER
	;;
esac
chmod uog+rw $ANSWER