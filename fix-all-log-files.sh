#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

checkExecutable repai-log files ${REPAIR_LOG_FILES}

if [ "$1" == "" ] ; then
	error "Plase specify and experiment ID"
	exit
fi

PROBE_DIR="${PROBE_BASE_DIR}/exp-$1"

if [ ! -d "${PROBE_DIR}" ] ; then
	echo "Probe measurements directory cannot be found at ${PROBE_DIR}"
	exit
fi

find ${PROBE_DIR} -name '*.dat' -exec ${REPAIR_LOG_FILES} -i {} \;

# end


