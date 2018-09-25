#!/bin/bash

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	error "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

JPETSTORE="$BASE_DIR/execute-jpetstore.sh"

###################################
# check setup

checkExecutable JPetStore "${JPETSTORE}"
checkFile log-configuration "${BASE_DIR}/log4j.cfg"
checkDirectory "data directory" "${DATA_DIR}"
checkExecutable "Privacy Analysis" "${PRIVACY_ANALYSIS}"

###################################
# start experiment

information "Deploying experiment..."

##
# Privacy Analysis

information "Start privacy analysis"

cat << EOF > privacy.config
## The name of the Kieker instance.
kieker.monitoring.name="${EXPERIMENT_ID}"
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# TCP collector
iobserve.analysis.source=org.iobserve.service.source.MultipleConnectionTcpCompositeStage
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.port=9876
org.iobserve.service.source.MultipleConnectionTcpCompositeStage.capacity=8192

# data storage
iobserve.analysis.model.pcm.databaseDirectory=$DB_DIR
iobserve.analysis.model.pcm.initializationDirectory=$PCM_DIR

# privacy configuration
iobserve.analysis.privacy.alarmFile=$BASE_DIR/alarms.txt
iobserve.analysis.privacy.warningFile=$BASE_DIR/warnings.txt
iobserve.analysis.privacy.modelDumpDirectory=$BASE_DIR/snapshots/

iobserve.analysis.privacy.policyList=NoPersonalDataInUSAPolicy
iobserve.analysis.privacy.packagePrefix=org.iobserve.service.privacy.violation.transformation.privacycheck.policies

iobserve.analysis.privacy.probeControls=localhost:4321

EOF

export SERVICE_PRIVACY_VIOLATION_OPTS=-Dlog4j.configuration=file:///$BASE_DIR/log4j-debug.cfg
${PRIVACY_ANALYSIS} -c privacy.config &
ANALYSIS_PID=$!

sleep 10

# run jpetstore
$JPETSTORE "$1"

# finally stop the collector
information "Stopping privacy analysis"

kill -TERM ${ANALYSIS_PID}
rm privacy.config

wait ${ANALYSIS_PID}

information "Experiment complete."

# end



