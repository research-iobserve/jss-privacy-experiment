#!/bin/bash

function run_exp() {
	echo "Starting $1 ..."
	./execute-migration-scenario.sh "$1" > "$1.log" 2>&1
	scp -r "executions/$1" reiner@192.168.48.213:/data/reiner/jss-experiments/execution-2/
        rm -rf "executions/$1"
}

#for I in 9 11 12 13 14 15 95 110 120 130 140 150 550 560 570 580 590 700 710 720 730 740 750 950 960 970 980 990 1010 1020 1030 1040 1050 ; do
#for I in 1030 1020 1040 1050 ; do
#	NAME="simulated-account-services-$I"
#	run_exp "$NAME"
#done

for I in 10 ; do
	NAME="simulated-account-services-med-$I"
	run_exp "$NAME"
done

# end

