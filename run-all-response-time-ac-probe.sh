#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
        . $BASE_DIR/config
else
        echo "Missing configuration"
        exit 1
fi

. $BASE_DIR/common-functions.sh

if [ "$1" == "" ] ; then
	error "Specify experiment host."
	exit
else
	HOST="$1"
fi

MEASUREMENT_DIR="$DATA_DIR/probe-experiment-$HOST"

checkDirectory data ${MEASUREMENT_DIR}

REPETITIONS=100

EXP=0
while [ $EXP -lt $REPETITIONS ] ; do
	export EXP=`expr $EXP + 1`
	echo "Experiment $EXP"

	if [ -d "${MEASUREMENT_DIR}/exp-$EXP" ] ; then
        	for I in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 30 40 50 60 70 80 90 95 100 110 120 130 140 150 200 300 400 500 550 560 570 580 590 600 700 710 720 730 740 750 800 900 950 960 970 980 990 1000 1010 1020 1030 1040 1050 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
	        	./execute-calc-probe-response-time.sh $I $MEASUREMENT_DIR/exp-$EXP
		done
	else
		echo "Not available"
    fi
done

# end
