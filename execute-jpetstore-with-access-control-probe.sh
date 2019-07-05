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

	WS_LOW=`expr $3 % 256`
	WS_HIGH=`expr $3 / 256`

	WE=`expr $3 + $1`
	WE_LOW=`expr $WE % 256`
	WE_HIGH=`expr $WE / 256`

	# information "blacklist $BS_HIGH.$BS_LOW - $BE_HIGH.$BE_LOW  whitelist $WS_HIGH.$WS_LOW - $WE_HIGH.$WE_LOW"

	export RUNTIME_RECONFIGURE_MONITORING_CONTROLLER_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j.cfg -Dkieker.monitoring.configuration=$CONTROL_TIME_PROPERTIES"
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

export PROBE_DATA_DIR="${DATA_DIR}/probe"

###################################
# create configurations
if [ ! -d "${PROBE_DATA_DIR}" ] ; then
	mkdir "${PROBE_DATA_DIR}"
fi

RESPONSE_TIME="${PROBE_DATA_DIR}/${LIST_SIZE}/response-time"
CONTROL_TIME="${PROBE_DATA_DIR}/${LIST_SIZE}/control-time"

if [ -d "${PROBE_DATA_DIR}/${LIST_SIZE}" ] ; then
	rm -rf "${PROBE_DATA_DIR}/${LIST_SIZE}/"
fi

mkdir -p "${RESPONSE_TIME}"
mkdir -p "${CONTROL_TIME}"

RESPONSE_TIME_PROPERTIES="$BASE_DIR/kieker-calc-response-time.properties"
CONTROL_TIME_PROPERTIES="$BASE_DIR/kieker-probe-control-time.properties"

cat << EOF > $RESPONSE_TIME_PROPERTIES
kieker.monitoring.name=KIEKER
kieker.monitoring.debug=false
kieker.monitoring.enabled=true
kieker.monitoring.hostname=
kieker.monitoring.initialExperimentId=1
kieker.monitoring.metadata=true
kieker.monitoring.setLoggingTimestamp=true
kieker.monitoring.useShutdownHook=true
kieker.monitoring.jmx=false

#######    TIMER    #######
kieker.monitoring.timer=kieker.monitoring.timer.SystemNanoTimer
kieker.monitoring.timer.SystemMilliTimer.unit=0
kieker.monitoring.timer.SystemNanoTimer.unit=0

#######    WRITER   #######
kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter
kieker.monitoring.core.controller.WriterController.RecordQueueFQN=org.jctools.queues.MpscArrayQueue
kieker.monitoring.core.controller.WriterController.RecordQueueSize=10000
kieker.monitoring.core.controller.WriterController.RecordQueueInsertBehavior=1

kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=$RESPONSE_TIME/
kieker.monitoring.writer.filesystem.FileWriter.charsetName=UTF-8
kieker.monitoring.writer.filesystem.FileWriter.maxEntriesInFile=25000
kieker.monitoring.writer.filesystem.FileWriter.maxLogSize=-1
kieker.monitoring.writer.filesystem.FileWriter.maxLogFiles=-1
kieker.monitoring.writer.filesystem.FileWriter.mapFileHandler=kieker.monitoring.writer.filesystem.TextMapFileHandler
kieker.monitoring.writer.filesystem.TextMapFileHandler.flush=true
kieker.monitoring.writer.filesystem.TextMapFileHandler.compression=kieker.monitoring.writer.compression.NoneCompressionFilter
kieker.monitoring.writer.filesystem.FileWriter.logFilePoolHandler=kieker.monitoring.writer.filesystem.RotatingLogFilePoolHandler
kieker.monitoring.writer.filesystem.FileWriter.logStreamHandler=kieker.monitoring.writer.filesystem.TextLogStreamHandler
kieker.monitoring.writer.filesystem.FileWriter.flush=false
kieker.monitoring.writer.filesystem.BinaryFileWriter.bufferSize=8192
kieker.monitoring.writer.filesystem.BinaryFileWriter.compression=kieker.monitoring.writer.compression.NoneCompressionFilter
EOF

cat << EOF > $CONTROL_TIME_PROPERTIES
kieker.monitoring.name=KIEKER
kieker.monitoring.debug=false
kieker.monitoring.enabled=true
kieker.monitoring.hostname=
kieker.monitoring.initialExperimentId=1
kieker.monitoring.metadata=true
kieker.monitoring.setLoggingTimestamp=true
kieker.monitoring.useShutdownHook=true
kieker.monitoring.jmx=false

#######    TIMER    #######
kieker.monitoring.timer=kieker.monitoring.timer.SystemNanoTimer
kieker.monitoring.timer.SystemMilliTimer.unit=0
kieker.monitoring.timer.SystemNanoTimer.unit=0

#######    WRITER   #######
kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter
kieker.monitoring.core.controller.WriterController.RecordQueueFQN=org.jctools.queues.MpscArrayQueue
kieker.monitoring.core.controller.WriterController.RecordQueueSize=10000
kieker.monitoring.core.controller.WriterController.RecordQueueInsertBehavior=1

kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=$CONTROL_TIME/
kieker.monitoring.writer.filesystem.FileWriter.charsetName=UTF-8
kieker.monitoring.writer.filesystem.FileWriter.maxEntriesInFile=25000
kieker.monitoring.writer.filesystem.FileWriter.maxLogSize=-1
kieker.monitoring.writer.filesystem.FileWriter.maxLogFiles=-1
kieker.monitoring.writer.filesystem.FileWriter.mapFileHandler=kieker.monitoring.writer.filesystem.TextMapFileHandler
kieker.monitoring.writer.filesystem.TextMapFileHandler.flush=true
kieker.monitoring.writer.filesystem.TextMapFileHandler.compression=kieker.monitoring.writer.compression.NoneCompressionFilter
kieker.monitoring.writer.filesystem.FileWriter.logFilePoolHandler=kieker.monitoring.writer.filesystem.RotatingLogFilePoolHandler
kieker.monitoring.writer.filesystem.FileWriter.logStreamHandler=kieker.monitoring.writer.filesystem.TextLogStreamHandler
kieker.monitoring.writer.filesystem.FileWriter.flush=false
kieker.monitoring.writer.filesystem.BinaryFileWriter.bufferSize=8192
kieker.monitoring.writer.filesystem.BinaryFileWriter.compression=kieker.monitoring.writer.compression.NoneCompressionFilter
EOF

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

export SELENIUM_EXPERIMENT_WORKLOADS_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j-info.cfg -Dkieker.monitoring.configuration=$RESPONSE_TIME_PROPERTIES"
$WORKLOAD_RUNNER -c $WORKLOAD_PATH -u "$SERVICE_URL" &
export WORKLOAD_PID=$!

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

# shutdown workload
kill -TERM $WORKLOAD_PID
sleep 10
kill -9 $WORKLOAD_PID

# shutdown jpetstore
stopDocker

# end

