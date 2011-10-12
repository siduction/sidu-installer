#! /bin/bash
pushd ..
DATE=$(date "+%H_%M")
TEMP=../tmp
ANSWER=$TEMP/fdisk_done.txt
cat <<EOS >$TEMP/shellserver-tasks/x$DATE.cmd
$ANSWER
std background
startgui
fdisk
/dev/sda
root
console
EOS

x=1
while [ $x -lt 20 ] ; do
        if [ -f $ANSWER ] ; then
		echo "Answer found:"
                cat $ANSWER
                rm $ANSWER                                                                                                    
                exit 0                                                                                                        
        fi                                                                                                                    
        x=$(expr $x + 1)                                                                                                      
        sleep 1
done
popd

