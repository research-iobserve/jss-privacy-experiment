#!/bin/bash

# simulate JPetStore run for different accounting setups

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

SIMULATOR="${TOOLS_DIR}/simulate-petstore-0.0.3-SNAPSHOT/bin/simulate-petstore"

checkExecutable "simulate petstore" "${SIMULATOR}"

###########################

declare -a SIMPID

# initial set
#for I in 1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800 900 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 ; do
# additional long set
# for I in 1 10 100 1000 10000 ; do
# additional edge cases
for I in 11 12 13 14 15 95 110 120 130 140 150 550 560 570 580 590 710 720 730 740 750 950 960 970 980 990 1010 1020 1030 1040 1050 ; do
	information "Generating data for $I accounting nodes."

#	EXPERIMENT_ID="simulated-account-services-long-$I"
	EXPERIMENT_ID="simulated-account-services-$I"
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

#	${SIMULATOR} -l GERMANY,USA -i 1000000 -d 100 -a $I &
	${SIMULATOR} -l GERMANY,USA -i 10000 -d 100 -a $I &
	SIMPID[$I]=$!
	sleep 10
done

for pid in ${SIMPID[@]}; do
	echo "wati for $pid"
	wait $pid
done

# end


