#!/bin/bash

## Execute a distributed JPetStore with docker locally.
## Utilize one workload model to drive the JPetStore or
## allow interactive mode.

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

# $1 = list size
# $2 = blacklist start
# $3 = whitelist start
# $4 = prefix AAA.BBB
function triggerNewLists() {
	BS_LOW=`expr $2 % 256`
	BS_HIGH=`expr $2 / 256`

	BE=`expr $2 + $1`
	BE_LOW=`expr $BE % 256`
	BE_HIGH=`expr $BE / 256`

	information "blacklist $BS_HIGH.$BS_LOW - $BE_HIGH.$BE_LOW"

	WS_LOW=`expr $3 % 256`
	WS_HIGH=`expr $3 / 256`

	WE=`expr $3 + $1`
	WE_LOW=`expr $WE % 256`
	WE_HIGH=`expr $WE / 256`

	information "whitelist $WS_HIGH.$WS_LOW - $WE_HIGH.$WE_LOW"

	export RUNTIME_RECONFIGURE_MONITORING_CONTROLLER_OPTS=-Dlog4j.configuration=file:///$BASE_DIR/log4j.cfg
	$AC_CONFIGURATION -bs "$4.$BS_HIGH.$BS_LOW" -be "$4.$BE_HIGH.$BE_LOW" \
		-h $ACCOUNT -p 5791 -ws "$4.$WS_HIGH.$WS_LOW" -we "$4.$WE_HIGH.$WE_LOW" -w $FRONTEND
}

###################################
# check parameters
if [ "$1" == "" ] ; then
	error "Cannot run experiment without workload."
	exit 1
else
	WORKLOAD_PATH="$1"
fi

if [ "$2" == "" ] ; then
	error "Need a number of nodes for the black- and whitelist."
	exit 1
else
	LIST_SIZE="$2"
fi

###################################
# check setup

checkExecutable workload-runner $WORKLOAD_RUNNER
checkExecutable web-driver $WEB_DRIVER
checkFile log-configuration $BASE_DIR/log4j.cfg

checkFile workload "$WORKLOAD_PATH"

information "Using workload ${WORKLOAD_PATH}"

###################################
# check if no leftovers are running

# stop docker
stopDocker

###################################
# starting

# jpetstore

information "Start jpetstore"

docker network create --driver bridge jpetstore-net

docker run -e LOGGER=$LOGGER -e LOCATION=GERMANY -d --name account --network=jpetstore-net jpetstore-account-service
docker run -e LOGGER=$LOGGER -d --name order --network=jpetstore-net jpetstore-order-service
docker run -e LOGGER=$LOGGER -d --name catalog --network=jpetstore-net jpetstore-catalog-service
docker run -e LOGGER=$LOGGER -d --name frontend --network=jpetstore-net jpetstore-frontend-service

ID=`docker ps | grep 'frontend' | awk '{ print $1 }'`
FRONTEND=`docker inspect $ID | grep '"IPAddress' | awk '{ print $2 }' | tail -1 | sed 's/^"\(.*\)",/\1/g'`

SERVICE_URL="http://$FRONTEND:8080/jpetstore-frontend"

information "Service URL $SERVICE_URL"

while ! curl -sSf $SERVICE_URL 2> /dev/null > /dev/null ; do
	echo "wait for service coming up..."
	sleep 1
done

ID=`docker ps | grep 'account' | awk '{ print $1 }'`
ACCOUNT=`docker inspect $ID | grep '"IPAddress' | awk '{ print $2 }' | tail -1 | sed 's/^"\(.*\)",/\1/g'`

# send configuration
WS=`expr 10 + $LIST_SIZE`
triggerNewLists $LIST_SIZE 2 $WS "10.10"

# check workload
information "Running workload driver"
read X

export SELENIUM_EXPERIMENT_WORKLOADS_OPTS=-Dlog4j.configuration=file:///$BASE_DIR/log4j.cfg
$WORKLOAD_RUNNER -c $WORKLOAD_PATH -u "$SERVICE_URL" -d "$WEB_DRIVER" &

ITERATION=0

REDEPLOYS=1000

while [ $ITERATION -lt $REDEPLOYS ] ; do
        ITERATION=`expr $ITERATION + 1`
	B_NET=`expr $ITERATION % 255`

	information "Loop $ITERATION -- B-net $B_NET"

	# send configuration
	WS=`expr 10 + $LIST_SIZE`
	triggerNewLists $LIST_SIZE 2 $WS "10.$B_NET"
done

sleep 10

###################################
# shutdown

# shutdown jpetstore
stopDocker

# end

