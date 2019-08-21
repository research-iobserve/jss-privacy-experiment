#!/bin/bash

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

REPETITIONS=100000
COUNT=1000

if [ "$1" == "" ] ; then
	RUN_TYPE="accounting-sans"
	CONTAINER="jpetstore-account-service-sans-effector"
	LIST_SIZE="NONE"
else
	RUN_TYPE="accounting/$1"
	CONTAINER="jpetstore-account-service"
	LIST_SIZE="$1"
fi

#############################################
# common functions

# stopping docker container
function stopDocker() {
	information "Stopping existing accounting instances ..."

	ACCOUNT=`docker ps -a --format '{{.Names}}' | grep account | wc -l`

	if [ "$ACCOUNT" -ge 1 ] ; then
		docker stop account
		docker rm account
	fi

	information "done"
}

# start docker container
function startDocker() {
	information "Start accounting component ..."

	docker run -e LOGGER=$LOGGER -e LOCATION=GERMANY -p 8080:8080 -p 5791:5791 -d --name account $CONTAINER

	ID=`docker ps | grep 'account' | awk '{ print $1 }'`
	ACCOUNT_SERVICE=`docker inspect $ID | grep '"IPAddress' | awk '{ print $2 }' | tail -1 | sed 's/^"\(.*\)",/\1/g'`

	SERVICE_URL="http://${ACCOUNT_SERVICE}:8080/jpetstore-account"

	information "Service URL $SERVICE_URL"

	while ! curl -sSf $SERVICE_URL 2> /dev/null > /dev/null ; do
		echo "wait for service coming up..."
		sleep 1
	done

	information "accounting is up"
}

###################################
# check parameters

###################################
# check if no leftovers are running

# stop docker
stopDocker

###################################
# run experiment

startDocker

touch ac.token

while [ -f ac.token ] ; do
	sleep 60
done

###################################
# complete experiment
stopDocker

# end




