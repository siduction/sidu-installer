#! /bin/bash
PROJ=sidu-installer
DIR_COVER=/tmp/cover-$PROJ
BROWSER=/usr/bin/opera
export PYTHONPATH="/home/ws/py/$PROJ:/home/ws/py/sidu-base:/usr/share/$PROJ:/usr/share/sidu-base:$PYTHONPATH"
if [ ! -f /usr/bin/nosetests ] ; then
	echo "missing packet python-nose"
	exit 1
fi
if [ ! -d /usr/share/pyshared/coverage ] ; then
	echo "missing packet python-coverage"
	exit 1
fi
rm -Rf $DIR_COVER
nosetests --with-coverage --cover-html --cover-html-dir=$DIR_COVER *test.py
if [ -x $BROWSER ] ; then
	$BROWSER $DIR_COVER/index.html
fi

