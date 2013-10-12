#! /bin/bash
OPT=$1
cd ../backend
ERRORS=0
perl $OPT autopart.pl test:../scripttest/ap_empty.data || ERRORS=$(expr $ERRORS + 1)

if [ $ERRORS > 0 ] ; then
	echo "+++ test with $ERRORS error(s) finished"
	exit 1
fi
