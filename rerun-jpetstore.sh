#!/bin/bash

while true ; do
	while [ ! -f ac.token ] ; do
		echo "Wait for token".
		sleep 10
	done
	echo "start jpetstore"
	./execute-only-jpetstore-with-access-control-probe.sh
done

# end
