#!/bin/bash

function run_exp() {
	echo "Starting $1 ..."
	./execute-migration-scenario-4-performance.sh "$1" > "$1.log" 2>&1
	scp -r "executions/$1" reiner@192.168.48.213:/data/reiner/jss-experiments/execution-2/
        rm -rf "executions/$1"
}

for I in $CONFIG_SET[complete] ; do
	NAME="simulated-account-services-$I"
	run_exp "$NAME"
done

# end

