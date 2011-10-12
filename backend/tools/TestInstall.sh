#! /bin/bash
pushd ..
TIME=$(date "+%H_%M_%S")
TEMP=../tmp
CMD=$TEMP/shellserver-tasks/task$TIME.cmd
ANSWER=$TEMP/answer$TIME.txt
PROGRESS=$TEMP/progress$TIME.txt
cat <<EOS >$CMD
$ANSWER
requestfile
install
progressfile=$PROGRESS
timezone=Europe/Berlin
rootpart=/dev/sda3
rootfs=ext4
mounts=/dev/sda3|/home|/dev/sdb3|/tmp/var
bootmanager=none
bootdest=mbr
ssh=0
rootpw=8935lf923
username=Jonny Weißmüller
login=jonny
pw=8935lf923
hostname=siductionbox
EOS
popd
