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

for I in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 30 40 50 60 70 80 90 95 100 110 120 130 140 150 200 300 400 500 550 560 570 580 590 600 700 710 720 730 740 750 800 900 950 960 970 980 990 1000 1010 1020 1030 1040 1050 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
	REPEAT=0
	while [ $REPEAT -lt $REPETITIONS ] ; do
		REPEAT=`expr $REPEAT + 1`
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

# end
