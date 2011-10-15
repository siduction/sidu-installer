#! /bin/bash
pushd ..
DATE=$(date "+%H_%M")
TEMP=../tmp
ANSWER=$TEMP/fdisk_done.txt
cat <<EOS >$TEMP/shellserver-tasks/x$DATE.cmd
$ANSWER
std background
startgui
gparted
/dev/sdb
root
std
EOS
x=1
while [ $x -lt 20 ] ; do
	if [ -f $ANSWER ] ; then
		cat $ANSWER
		rm $ANSWER
		exit 0
	fi
	x=$(expr $x + 1)
	sleep 1
done
popd
