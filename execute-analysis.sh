#!/bin/bash

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

cat << EOF > $BASE_DIR/privacy.config
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

iobserve.analysis.source=org.iobserve.service.source.MultipleConnectionTcpCompositeStage
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.port=9876
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.capacity=8192

# data storage
iobserve.analysis.model.pcm.databaseDirectory=/home/reiner/Projects/iObserve/experiments/jss-privacy-experiment/db/
iobserve.analysis.model.pcm.initializationDirectory=/home/reiner/Projects/iObserve/experiments/jss-privacy-experiment/pcm/

# privacy configuration
iobserve.analysis.privacy.alarmFile=/home/reiner/Projects/iObserve/experiments/jss-privacy-experiment/alarms.txt
iobserve.analysis.privacy.warningFile=/home/reiner/Projects/iObserve/experiments/jss-privacy-experiment/warnings.txt
iobserve.analysis.privacy.modelDumpDirectory=/home/reiner/Projects/iObserve/experiments/jss-privacy-experiment/snapshots/

iobserve.analysis.privacy.policyList=NoPersonalDataInUSAPolicy
iobserve.analysis.privacy.packagePrefix=org.iobserve.service.privacy.violation.transformation.privacycheck.policies

iobserve.analysis.privacy.probeControls=localhost:4321
EOF

SERVICE_PRIVACY_VIOLATION_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg -Dkieker.monitoring.configuration=$BASE_DIR/kieker.properties"
${PRIVACY_ANALYSIS} -c $BASE_DIR/privacy.config &
PRIVACY_ANALYSIS_PID=$!

information "Wait for service to be started properly"
sleep 60

information "Starting replayer"

KIEKER=`ls $DATA_DIR | grep "kieker-"`

REPLAYER_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg"
${REPLAYER} -p 9876 -i $DATA_DIR/$KIEKER/  -h localhost -r -c 100 -d 4

kill -TERM $PRIVACY_ANALYSIS_PID
sleep 10
kill -9 $PRIVACY_ANALYSIS_PID

rm $BASE_DIR/privacy.config

information "Experiment complete."

# end
