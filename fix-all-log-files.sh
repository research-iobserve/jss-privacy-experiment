#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

PROBE_DIR="/home/reiner/data/probe-experiment/exp-1"

find ${PROBE_DIR} -name '*.dat' -exec ${TOOLS_DIR}/repair-log-files-0.0.3-SNAPSHOT/bin/repair-log-files -i {} \;

# end


