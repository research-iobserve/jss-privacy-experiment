#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

STORAGE="reiner@192.168.48.213:/data/reiner/jss-experiments/probe-experiment/"

REPETITIONS="100"
ACOUNT_SET="complete"

touch ac.token

REPEAT=0
while [ $REPEAT -lt $REPETITIONS ] ; do
	REPEAT=`expr $REPEAT + 1`
	echo "Experiment repetitions $REPEAT"
	for I in $CONFIG_SET[$ACCOUNT_SET] ; do
		echo "Running $I"
		$BASE_DIR/execute-jpetstore-with-access-control-effector.sh $BASE_DIR/workloads/account-intense.yaml $I $REPEAT > ac-$I.log 2>&1
		echo "Done $I"

#		scp -r "${DATA_DIR}/probe/exp-${EXPERIMENT}" "${STORAGE}/"

		echo "End cool down $I"
	done
done
# end
