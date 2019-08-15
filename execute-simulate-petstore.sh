#!/bin/bash

# Simulate JPetStore deployment changes over time.

# Parameter:
# $1 = number of redeployments
# $2 = configuration set
# $3 = experiment identifier prefix

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

##########################
# check parameters

if [ "$1" == "" ] ; then
	error "Requires the number of redeployments."
	exit 1
fi

if [ "$2" == "" ] ; then
	error "You must define which set of JPetStore configurations you want to use. Choose one of ${!CONFIG_SET[@]}"
	exit 1
else
	legal="false"
	for I in ${!CONFIG_SET[@]} ; do
		if [ "$I" == "$2" ] ; then
			legal="true"
			ACCOUNT_SET="$I"
		fi
	done
	if [ "$legal" != "true" ] ; then
		error "$2 is not a valid set."
		error "You must define which set of JPetStore configurations you want to use. Choose one of ${!CONFIG_SET[@]}"
		exit 1
	fi
fi

if [ "$3" == "" ] ; then
	error "You must specify an experiment base name, e.g., simulated-account-services"
	exit 1
fi

REDEPLOYMENTS="$1"
EXPERIMENT_ID_PREFIX="$3"

checkExecutable "simulate petstore" "${SIMULATE_PETSTORE}"

###########################

declare -a SIMPID

for I in $CONFIG_SET[$ACCOUNT_SET] ; do
	information "Generating data for $I accounting nodes."

	EXPERIMENT_ID="$EXPERIMENT_ID_PREFIX-$I"
	RESULT_DIR="${DATA_DIR}/input/${EXPERIMENT_ID}"

	mkdir -p "${RESULT_DIR}"

cat << EOF > "${BASE_DIR}/simulate-petstore-kieker.properties"
kieker.monitoring.name=KIEKER
kieker.monitoring.debug=false
kieker.monitoring.enabled=true
kieker.monitoring.hostname=
kieker.monitoring.initialExperimentId=$I
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

kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=${RESULT_DIR}
kieker.monitoring.writer.filesystem.FileWriter.charsetName=UTF-8
kieker.monitoring.writer.filesystem.FileWriter.maxEntriesInFile=25000
kieker.monitoring.writer.filesystem.FileWriter.maxLogSize=-1
kieker.monitoring.writer.filesystem.FileWriter.maxLogFiles=-1
kieker.monitoring.writer.filesystem.FileWriter.mapFileHandler=kieker.monitoring.writer.filesystem.TextMapFileHandler
kieker.monitoring.writer.filesystem.TextMapFileHandler.flush=true
kieker.monitoring.writer.filesystem.TextMapFileHandler.compression=kieker.monitoring.writer.filesystem.compression.NoneCompressionFilter
kieker.monitoring.writer.filesystem.FileWriter.logFilePoolHandler=kieker.monitoring.writer.filesystem.RotatingLogFilePoolHandler
kieker.monitoring.writer.filesystem.FileWriter.logStreamHandler=kieker.monitoring.writer.filesystem.TextLogStreamHandler
kieker.monitoring.writer.filesystem.FileWriter.flush=false
kieker.monitoring.writer.filesystem.BinaryFileWriter.bufferSize=8192
kieker.monitoring.writer.filesystem.BinaryFileWriter.compression=kieker.monitoring.writer.filesystem.compression.NoneCompressionFilter
EOF

        export SIMULATE_PETSTORE_OPTS="-Dkieker.monitoring.configuration=${BASE_DIR}/simulate-petstore-kieker.properties"

	${SIMULATE_PETSTORE} -l GERMANY,USA -i $REDEPLOYMENTS -d 100 -a $I &
	SIMPID[$I]=$!
	sleep 10

	rm "${BASE_DIR}/simulate-petstore-kieker.properties"
done

# Stop simulators
for pid in ${SIMPID[@]}; do
	echo "wait for $pid"
	wait $pid
done

# end


