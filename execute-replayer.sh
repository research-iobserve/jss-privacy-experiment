#!/bin/bash

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

###################################
# check setup

DATA="${BASE_DIR}/data/kieker-20181212-114505-183120283920942-UTC--/"

###################################
# check setup

${TOOLS_DIR}/replayer-0.0.3-SNAPSHOT/bin/replayer -p 9876 -i "$DATA" -h localhost -r -c 100 -d 4

# end

