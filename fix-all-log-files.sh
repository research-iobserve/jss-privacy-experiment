#!/bin/bash

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
	error "Plase specify an data source identifier"
	exit
fi

if [ "$2" == "" ] ; then
	error "Plase specify and experiment ID"
	exit
fi

PROBE_DIR="$1/exp-$2"

if [ ! -d "${PROBE_DIR}" ] ; then
	echo "Probe measurements directory cannot be found at ${PROBE_DIR}"
	exit
fi

for I in `find ${PROBE_DIR}/ -name '*.dat' | grep -v "control-time"` ; do
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


