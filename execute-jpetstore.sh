#!/bin/bash

# parameter
# $1 = workload driver configuration (optional)

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

#############################################
# common functions

# stopping docker container
function stopDocker() {
	information "Stopping existing distributed jpetstore instances ..."

	docker stop frontend
	docker stop order
	docker stop catalog
	docker stop account

	docker rm frontend
	docker rm order
	docker rm catalog
	docker rm account

	docker network rm jpetstore-net

	information "done"
}

###################################
# check parameters
if [ "$1" == "" ] ; then
	export INTERACTIVE="yes"
	information "Interactive mode no specialized workload driver"
else
	export INTERACTIVE="no"
	checkFile workload "$1"
	WORKLOAD_PATH="$1"
	information "Automatic mode, workload driver is ${WORKLOAD_PATH}"
fi

###################################
# check setup

if [ "$INTERACTIVE" == "no" ] ; then
	checkExecutable workload-runner $WORKLOAD_RUNNER
	checkExecutable wbe-driver $WEB_DRIVER
	checkFile log-configuration $BASE_DIR/log4j.cfg
fi

###################################
# check if no leftovers are running

# stop docker
stopDocker

###################################
# starting

# jpetstore

information "Start jpetstore"

docker network create --driver bridge jpetstore-net

docker run -e LOGGER=$LOGGER -d --name account --network=jpetstore-net jpetstore-account-service
docker run -e LOGGER=$LOGGER -d --name order --network=jpetstore-net jpetstore-order-service
docker run -e LOGGER=$LOGGER -d --name catalog --network=jpetstore-net jpetstore-catalog-service
docker run -e LOGGER=$LOGGER -d --name frontend --network=jpetstore-net jpetstore-frontend-service

ID=`docker ps | grep 'frontend' | awk '{ print $1 }'`
FRONTEND=`docker inspect $ID | grep '"IPAddress' | awk '{ print $2 }' | tail -1 | sed 's/^"\(.*\)",/\1/g'`

SERVICE_URL="http://$FRONTEND:8080/jpetstore-frontend"

information "Service URL $SERVICE_URL"

while ! curl -sSf $SERVICE_URL ; do
	sleep 1
done

# check workload
if [ "$INTERACTIVE" == "yes" ] ; then
	information "You may now use JPetStore"
	information "Press Enter to stop the service"
	read
else
	information "Running workload driver"

        export SELENIUM_EXPERIMENT_WORKLOADS_OPTS=-Dlog4j.configuration=file:///$BASE_DIR/log4j.cfg
        $WORKLOAD_RUNNER -c $WORKLOAD_PATH -u "$SERVICE_URL" -d "$WEB_DRIVER"

        sleep 10	
fi
	
###################################
# shutdown

# shutdown jpetstore
stopDocker

# end

