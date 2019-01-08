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

information "Interactive mode no specialized workload driver"

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

SERVICE_URL="http://$FRONTEND:8080/jpetstore-frontend/"

information "Service URL $SERVICE_URL"

while ! curl -sSf $SERVICE_URL 2> /dev/null > /dev/null ; do
	echo "wait for service coming up..."
	sleep 1
done

ITERATION=0

while [ $ITERATION -lt 10000 ] ; do
	ITERATION=`expr $ITERATION + 1`
	echo "Redeployment $ITERATION"

	if [ $(( $ITERATION % 2)) -eq 0 ]; then
		export LOCATION="USA"
	else
		export LOCATION="GERMANY"
	fi

	docker stop -t 30 account > /dev/null
	docker rm account > /dev/null
	docker run -e LOGGER=$LOGGER -e LOCATION=$LOCATION -d --name account --network=jpetstore-net jpetstore-account-service > /dev/null

	ACCOUNT_ID=`docker ps | grep 'account' | awk '{ print $1 }'`
	ACCOUNT=`docker inspect $ACCOUNT_ID | grep '"IPAddress' | awk '{ print $2 }' | tail -1 | sed 's/^"\(.*\)",/\1/g'`

	ACCOUNT_URL="http://$ACCOUNT:8080/jpetstore-account/request-user?username=j2ee"

	while ! curl -sSf $ACCOUNT_URL 2> /dev/null > /dev/null ; do
		echo "wait for service coming up..."
		sleep 1
	done
done

###################################
# shutdown

# shutdown jpetstore
stopDocker

# end

