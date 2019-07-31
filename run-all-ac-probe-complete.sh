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

touch ac.token

REPEAT=0
while [ $REPEAT -lt $REPETITIONS ] ; do
	REPEAT=`expr $REPEAT + 1`
	echo "Experiment repetitions $REPEAT"
#	for I in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 30 40 50 60 70 80 90 95 100 110 120 130 140 150 200 300 400 500 550 560 570 580 590 600 700 710 720 730 740 750 800 900 950 960 970 980 990 1000 1010 1020 1030 1040 1050 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
	for I in 560 570 580 590 600 700 710 720 730 740 750 800 900 950 960 970 980 990 1000 1010 1020 1030 1040 1050 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
		echo "Running $I"
		./execute-jpetstore-with-access-control-probe.sh workloads/account-intense.yaml $I $REPEAT > ac-$I.log 2>&1
		echo "Done $I"

#		scp -r "${DATA_DIR}/probe/exp-${EXPERIMENT}" "${STORAGE}/"

		echo "End cool down $I"
	done
done
# end
