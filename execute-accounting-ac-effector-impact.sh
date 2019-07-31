#!/bin/bash

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

	docker run -e LOGGER=$LOGGER -e LOCATION=GERMANY -d --name account jpetstore-account-service

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
	${DRIVE_ACCOUNTING} -u $1 -d 100 -c 1000 -r 100000
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
function configureEffector() {
	information "Running effector configuration"
	RUNTIME_RECONFIGURE_MONITORING_CONTROLLER_OPTS="-Dlog4j.configuration=file:///${BASE_DIR}/log4j.cfg"
	${AC_CONFIGURATION} -h "${ACCOUNT_SERVICE}" -p 5791 -ws 10.0.0.1 -we 10.0.39.21 -bs 10.1.0.1 -be 10.0.39.21 -w 172.17.0.1 172.17.0.1
	information "done"
}

###################################
# check parameters

ACCOUNTING_KIEKER_PROPERTIES="$BASE_DIR/kieker-drive-accounting.properties"
COLLECTOR_PROPERTIES="$BASE_DIR/kieker-collector.properties"

export STORAGE_PATH="${DATA_DIR}/accounting/responses"
export COLLECTOR_DATA_PATH="${DATA_DIR}/accounting/collector"

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

configureEffector

driveService "${SERVICE_URL}"

###################################
# complete experiment
stopDocker

stopCollector

# end




