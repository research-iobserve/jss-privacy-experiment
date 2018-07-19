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

function stopKube() {
	information "Stopping existing distributed jpetstore instances ..."

	kubectl delete --grace-period=60 service/jpetstore
	for I in frontend account catalog order ; do
		kubectl delete --grace-period=120 pods/$I
	done
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


###################################
# starting

# jpetstore

information "Start jpetstore"

# initial deployment
cat $KUBERNETES_DIR/jpetstore.yaml | sed "s/%LOGGER%/$LOGGER/g" > start.yaml
cat $KUBERNETES_DIR/usa.yaml | sed "s/%LOGGER%/$LOGGER/g" > additional.yaml
kubectl create -f start.yaml

rm start.yaml

# check if service is running

FRONTEND=""
while [ "$FRONTEND" == "" ] ; do
	ID=`kubectl get pods | grep frontend | awk '{ print $1 }'`
	FRONTEND=`kubectl describe pods/$ID | grep "IP:" | awk '{ print $2 }'`
done

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
        $WORKLOAD_RUNNER -c $WORKLOAD_PATH -u "$SERVICE_URL" -d "$WEB_DRIVER" &
	WORKLOAD_RUNNER_PID=$!

        sleep 10	
fi

# delay
information "Wait for deployment change"
sleep 30

# modification
information "Perform deployment change"
kubectl replace -f additional.yaml --force

# wait for scenario end
information "Wait for scenario end"
wait $WORKLOAD_RUNNER_PID


# shutdown jpetstore
stopKube

sleep 120

# shutdown analysis/collector
information "Term Analysis"

kill -TERM ${COLLECTOR_PID}
rm collector.config

information "Done."
# end
