#!/bin/bash

# Fix kieker log files.

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

checkExecutable repair-log-files ${REPAIR_LOG_FILES}

if [ "$1" == "" ] ; then
	error "Please specify a Kieker log directory"
	exit
fi

KIEKER_DIR="$1"

if [ ! -d "${KIEKER_DIR}" ] ; then
	error "Probe measurements directory cannot be found at ${KIEKER_DIR}"
	exit
fi

for I in `find ${KIEKER_DIR}/ -name '*.dat'` ; do
	echo $I
	${REPAIR_LOG_FILES} -i $I
	if [ -f "$I" ] ; then
		size=$(stat -c%s $I)
		if [ $size -ge 0 ] ; then
			rm $I.old
		fi
	fi
done

# end


