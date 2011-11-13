#! /bin/bash
ANSWER=$1
/sbin/reboot
touch $ANSWER
chmod uog+rw $ANSWER
