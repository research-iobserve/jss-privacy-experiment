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

# stop kube deployment
function stopKube() {
	information "Stopping existing distributed jpetstore instances ..."

	kubectl delete --grace-period=60 service/jpetstore
	for I in frontend account catalog order ; do
		kubectl delete --grace-period=120 pods/$I
	done

	information "Done"
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

checkFile jpetstore-configuration $KUBERNETES_DIR/jpetstore.yaml
checkFile usa-configuration $KUBERNETES_DIR/account-pod.yaml

###################################
# check if no leftovers are running


###################################
# starting

# jpetstore

information "Start jpetstore"

# initial deployment
export LOCATION="GERMANY"
cat $KUBERNETES_DIR/jpetstore.yaml | sed "s/%LOGGER%/$LOGGER/g" | sed "s%LOCATION%/$LOCATION" > start.yaml
cat $KUBERNETES_DIR/account-pod.yaml | sed "s/%LOGGER%/$LOGGER/g" | sed "s%LOCATION%/$LOCATION" > additional.yaml
kubectl create -f start.yaml
kubectl create -f additional.yaml

rm start.yaml

# check if service is running

FRONTEND=""
while [ "$FRONTEND" == "" ] ; do
	ID=`kubectl get pods | grep frontend | awk '{ print $1 }'`
	FRONTEND=`kubectl describe pods/$ID | grep "IP:" | awk '{ print $2 }'`
done

SERVICE_URL="http://$FRONTEND:8080/jpetstore-frontend"

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

	cat $KUBERNETES_DIR/account-pod.yaml | sed "s/%LOGGER%/$LOGGER/g" | sed "s%LOCATION%/$LOCATION" > additional.yaml

	kubectl replace -f additional.yaml --force

	rm additional.yaml

done

###################################
# shutdown

# shutdown jpetstore
stopKube

sleep 120

# shutdown analysis/collector
information "Term Analysis"

kill -TERM ${COLLECTOR_PID}
rm collector.config

information "Done."

# end

