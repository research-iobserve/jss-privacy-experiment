#!/bin/bash

# run privacy analysis based on observed and logged events.

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

PRIVACY_ANALYSIS="$TOOLS_DIR/service.privacy.violation-0.0.3-SNAPSHOT/bin/service.privacy.violation"
REPLAYER="$TOOLS_DIR/replayer-0.0.3-SNAPSHOT/bin/replayer"

checkExecutable "privacy analysis" "${PRIVACY_ANALYSIS}"
checkExecutable "replayer" "${REPLAYER}"

###################################

information "Starting privacy analysis"

PRIVACY_KIEKER_PROPERTIES=$BASE_DIR/privacy.kieker.properties

mkdir $DATA_DIR/privacy

##
## configuration for monitoring the privacy analysis
##
cat << EOF > ${PRIVACY_KIEKER_PROPERTIES}
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

kieker.monitoring.writer.filesystem.FileWriter.customStoragePath=$DATA_DIR/privacy
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


##
## configuration of the privacy analysis
##
cat << EOF > $BASE_DIR/privacy.config
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

iobserve.analysis.source=org.iobserve.service.source.MultipleConnectionTcpCompositeStage
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.port=9876
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.capacity=8192

# data storage
iobserve.analysis.model.pcm.databaseDirectory=$BASE_DIR/db/
iobserve.analysis.model.pcm.initializationDirectory=$BASE_DIR/pcm/

# privacy configuration
iobserve.analysis.privacy.alarmFile=$BASE_DIR/alarms.txt
iobserve.analysis.privacy.warningFile=$BASE_DIR/warnings.txt
iobserve.analysis.privacy.modelDumpDirectory=$BASE_DIR/snapshots/

iobserve.analysis.privacy.policyList=NoPersonalDataInUSAPolicy
iobserve.analysis.privacy.packagePrefix=org.iobserve.service.privacy.violation.transformation.privacycheck.policies

iobserve.analysis.privacy.probeControls=localhost:4321
EOF

##
## running privacy analysis
##
SERVICE_PRIVACY_VIOLATION_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg -Dkieker.monitoring.configuration=${PRIVACY_KIEKER_PROPERTIES}"
${PRIVACY_ANALYSIS} -c $BASE_DIR/privacy.config &
PRIVACY_ANALYSIS_PID=$!

information "Wait for service to be started properly"
sleep 60

information "Starting replayer"

KIEKER=`ls $DATA_DIR | grep "kieker-"`

##
## running event replayer
##
REPLAYER_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg"
${REPLAYER} -p 9876 -i $DATA_DIR/$KIEKER/  -h localhost -r -c 100 -d 4

kill -TERM $PRIVACY_ANALYSIS_PID
sleep 10
kill -9 $PRIVACY_ANALYSIS_PID

rm $BASE_DIR/privacy.config

information "Experiment complete."

# end
