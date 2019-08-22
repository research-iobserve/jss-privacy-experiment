#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
        . $BASE_DIR/config
else
        echo "Missing configuration"
        exit 1
fi

. $BASE_DIR/common-functions.sh

# compute base line
# $BASE_DIR/execute-accounting-ac-effector-impact.sh

# compute effector configurations
for I in 10 100 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
	information "Running $I ..."
	$BASE_DIR/execute-accounting-ac-effector-impact-driver.sh "$I"
	information "done"
	scp -r data/accounting reiner@192.168.48.213:/data/reiner/jss-experiments/pi/
	rm -rf data/accounting/$I
	sleep 120
done

# end
