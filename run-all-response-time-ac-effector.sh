#!/bin/bash

# Recalculates response times for all performance runs of the effector

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

MEASUREMENT_DIR="$DATA_DIR/effector/$HOST"

checkDirectory data ${MEASUREMENT_DIR}

REPETITIONS=100

EXP=0
while [ $EXP -lt $REPETITIONS ] ; do
	export EXP=`expr $EXP + 1`
	echo "Experiment $EXP"

	if [ -d "${MEASUREMENT_DIR}/exp-$EXP" ] ; then
        	for I in $CONFIG_SET[complete] ; do
	        	./calc-response-time.sh $I $MEASUREMENT_DIR/exp-$EXP
		done
	else
		echo "Not available"
    fi
done

# end
