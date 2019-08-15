#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

while true ; do
	while [ ! -f ac.token ] ; do
		information "Wait for token".
		sleep 10
	done
	information "start jpetstore"
	$BASE_DIR/execute-only-jpetstore-with-access-control-effector.sh
done

# end
