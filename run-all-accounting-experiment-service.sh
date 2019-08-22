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
#$BASE_DIR/execute-accounting-ac-effector-impact.sh

# compute effector configurations
for I in 10 100 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
	information "Waiting $I ..."
	while [ ! -f ac.wait ] ; do
		sleep 100
	done
	rm ac.wait
	information "Running $I ..."
	$BASE_DIR/execute-accounting-ac-effector-impact-service.sh "$I"
done

# end
