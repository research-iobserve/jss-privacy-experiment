#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

FRONTEND="192.168.48.223"
SERVICE_URL="http://$FRONTEND:8080/jpetstore-frontend"

STORAGE="reiner@192.168.48.213:/data/reiner/jss-experiments/probe-experiment/"

REPETITIONS="100"

touch ac.token

REPEAT=0
while [ $REPEAT -lt $REPETITIONS ] ; do
	REPEAT=`expr $REPEAT + 1`
	echo "Experiment repetitions $REPEAT"
	for I in $CONFIG_SET[complete] ; do
		echo "Set ac.token"
		scp ac.token pi@$FRONTEND:~/jss-privacy-experiment/

		while ! curl -sSf $SERVICE_URL 2> /dev/null > /dev/null ; do
			echo "waiting for service coming up..."
			sleep 10
		done

		echo "Running $I"
		./execute-control-4-jpetstore.sh workloads/account.yaml $I $REPEAT > ac-$I.log 2>&1
		echo "Done $I"
		ssh pi@$FRONTEND "rm -f ~/jss-privacy-experiment/ac.token"

		scp -r "${DATA_DIR}/probe/exp-${EXPERIMENT}" "${STORAGE}/"

		sleep 200
		echo "End cool down $I"
	done
done
# end
