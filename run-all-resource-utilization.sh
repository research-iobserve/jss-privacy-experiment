#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
        . $BASE_DIR/config
else
        echo "Missing configuration"
        exit 1
fi

. $BASE_DIR/common-functions.sh


function run_exp() {
	echo "Starting $1 ..."
	mkdir "executions/$1"
	./execute-migration-scenario-4-resource-utilization.sh "$1" > "$1.log" 2>&1
	scp -r "executions/$1" reiner@192.168.48.213:/data/reiner/jss-experiments/pi/resource-utilization/
        rm -rf "executions/$1"
}

for I in ${CONFIG_SET["resource"]} ; do
	NAME="simulated-account-services-$I"
	run_exp "$NAME"
done

# end

