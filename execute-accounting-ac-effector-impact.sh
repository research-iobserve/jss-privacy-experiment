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

	docker run -e LOGGER=$LOGGER -e LOCATION=GERMANY -d --name account $CONTAINER

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

# drive service
function driveService() {
	information "Run accounting driver"

cat << EOF > $ACCOUNTING_KIEKER_PROPERTIES
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

kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=$STORAGE_PATH/
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

        export DRIVE_ACCOUNTING_OPTS="-Dlog4j.configuration=file:///${BASE_DIR}/log4j.cfg -Dkieker.monitoring.configuration=${ACCOUNTING_KIEKER_PROPERTIES}"
	${DRIVE_ACCOUNTING} -u $1 -d 100 -c $COUNT -r $REPETITIONS
}

# run collector
function startCollector() {
	information "Start collector"

cat << EOF > $COLLECTOR_PROPERTIES
# common
kieker.monitoring.name=0
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# TCP collector
iobserve.service.reader=org.iobserve.service.source.MultipleConnectionTcpCompositeStage
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.port=9876
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.capacity=81920

# dump stage
kieker.monitoring.writer=kieker.monitoring.writer.filesystem.FileWriter
kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=${COLLECTOR_DATA_PATH}
kieker.monitoring.writer.filesystem.FileWriter.charsetName=UTF-8
kieker.monitoring.writer.filesystem.FileWriter.maxEntriesInFile=25000
kieker.monitoring.writer.filesystem.FileWriter.maxLogSize=-1
kieker.monitoring.writer.filesystem.FileWriter.maxLogFiles=-1
kieker.monitoring.writer.filesystem.FileWriter.mapFileHandler=kieker.monitoring.writer.filesystem.TextMapFileHandler
kieker.monitoring.writer.filesystem.TextMapFileHandler.flush=true
kieker.monitoring.writer.filesystem.TextMapFileHandler.compression=kieker.monitoring.writer.filesystem.compression.NoneCompressionFilter
kieker.monitoring.writer.filesystem.FileWriter.logFilePoolHandler=kieker.monitoring.writer.filesystem.RotatingLogFilePoolHandler
kieker.monitoring.writer.filesystem.FileWriter.logStreamHandler=kieker.monitoring.writer.filesystem.TextLogStreamHandler
kieker.monitoring.writer.filesystem.FileWriter.flush=true
kieker.monitoring.writer.filesystem.FileWriter.bufferSize=81920
EOF
        export COLLECTOR_OPTS="-Dlog4j.configuration=file:///${BASE_DIR}/log4j.cfg"
	$COLLECTOR -c "${COLLECTOR_PROPERTIES}" &
	COLLECTOR_PID=$!

	information "done"
}

# stop collector
function stopCollector() {
	information "Stopping collector"

	kill -TERM ${COLLECTOR_PID}
	rm $COLLECTOR_PROPERTIES

	wait ${COLLECTOR_PID}

	information "Experiment complete."
}

# configure effector
# $1 = list size
function configureEffector() {
	information "Running effector configuration"

	PREFIX="10.10"

	B_BASE="1"
	W_BASE=`expr $1 + 10`

        BS_LOW=`expr $B_BASE % 256`
        BS_HIGH=`expr $B_BASE / 256`

        BE=`expr $B_BASE + $1`
        BE_LOW=`expr $BE % 256`
        BE_HIGH=`expr $BE / 256`

        WS_LOW=`expr $W_BASE % 256`
        WS_HIGH=`expr $W_BASE / 256`

        WE=`expr $W_BASE + $1`
        WE_LOW=`expr $WE % 256`
        WE_HIGH=`expr $WE / 256`

        information "blacklist $BS_HIGH.$BS_LOW - $BE_HIGH.$BE_LOW  whitelist $WS_HIGH.$WS_LOW - $WE_HIGH.$WE_LOW"

        export RUNTIME_RECONFIGURE_MONITORING_CONTROLLER_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j.cfg -Dkieker.monitoring.configuration=$CONTROL_TIME_PROPERTIES"
        $AC_CONFIGURATION -bs "$PREFIX.$BS_HIGH.$BS_LOW" -be "$PREFIX.$BE_HIGH.$BE_LOW" \
                -h "${ACCOUNT_SERVICE}" -p 5791 -ws "$PREFIX.$WS_HIGH.$WS_LOW" -we "$PREFIX.$WE_HIGH.$WE_LOW" -w 172.17.0.1 "${ACCOUNT_SERVICE}"

	information "done"
}


###################################
# check parameters

ACCOUNTING_KIEKER_PROPERTIES="$BASE_DIR/kieker-drive-accounting.properties"
COLLECTOR_PROPERTIES="$BASE_DIR/kieker-collector.properties"

export STORAGE_PATH="${DATA_DIR}/${RUN_TYPE}/responses"
export COLLECTOR_DATA_PATH="${DATA_DIR}/${RUN_TYPE}/collector"

checkExecutable access-control "$AC_CONFIGURATION"
checkExecutable collector "$COLLECTOR"
checkExecutable drive-accounting "$DRIVE_ACCOUNTING"
checkDirectory data-dir "${DATA_DIR}"

if [ -d "${STORAGE_PATH}" ] ; then
	rm -rf "${STORAGE_PATH}"
fi
if [ -d "${COLLECTOR_DATA_PATH}" ] ; then
	rm -rf "${COLLECTOR_DATA_PATH}"
fi

mkdir -p "${STORAGE_PATH}"
mkdir -p "${COLLECTOR_DATA_PATH}"

###################################
# check if no leftovers are running

# stop docker
stopDocker

###################################
# run experiment

startCollector

sleep 10

startDocker

if [ "${LIST_SIZE}" != "NONE" ] ; then
	configureEffector "${LIST_SIZE}"
else
	information "no effector"
fi

driveService "${SERVICE_URL}"

###################################
# complete experiment
stopDocker

stopCollector

# end




