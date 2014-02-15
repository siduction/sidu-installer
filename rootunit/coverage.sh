#! /bin/bash
PROJ=sidu-installer
DIR_COVER=/tmp/cover-root-$PROJ
BROWSER=/usr/bin/opera
export PYTHONPATH="/home/ws/py/$PROJ:/home/ws/py/$PROJ/backend:/home/ws/py/sidu-base:/usr/share/$PROJ:/usr/share/sidu-base:$PYTHONPATH"
if [ ! -f /usr/bin/nosetests ] ; then
	echo "missing packet python-nose"
	exit 1
fi
if [ ! -d /usr/share/pyshared/coverage ] ; then
	echo "missing packet python-coverage"
	exit 1
fi
if [ ! -f /usr/share/javascript/jquery-hotkeys/jquery.hotkeys.js ] ; then
	echo "missing packet libjs-jquery-hotkeys"
	exit 1
fi
if [ ! -f /usr/share/javascript/jquery-isonscreen/jquery.isonscreen.js ] ; then
	echo "missing packet libjs-jquery-isonscreen"
	exit 1
fi
if [ ! -f /usr/share/javascript/jquery-tablesorter/jquery.tablesorter.min.js ] ; then
	echo "missing packet libjs-jquery-tablesorter"
	exit 1
fi	
rm -Rf $DIR_COVER
nosetests --with-coverage --cover-html --cover-html-dir=$DIR_COVER *test.py
if [ -x $BROWSER ] ; then
	$BROWSER $DIR_COVER/index.html
fi

