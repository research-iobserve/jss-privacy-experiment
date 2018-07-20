#!/bin/bash

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

. $BASE_DIR/common-functions.sh

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	error "Missing configuration"
	exit 1
fi

#########################################
# parameter evaluation

if [ "$1" == "" ] ; then
	error "Usage: $0 <EXPERIMENT ID>"
	exit 1
fi

export EXPERIMENT_ID="$1"
export INPUT_DATA_DIR="${DATA_DIR}/${EXPERIMENT_ID}"

# compute setup
if [ -f $INPUT_DATA_DIR/kieker.map ] ; then
	KIEKER_DIRECTORIES=$INPUT_DATA_DIR
else
	KIEKER_DIRECTORIES=""
	for D in `ls $INPUT_DATA_DIR` ; do
		if [ -f $INPUT_DATA_DIR/$D/kieker.map ] ; then
			if [ "$KIEKER_DIRECTORIES" == "" ] ;then
				KIEKER_DIRECTORIES="$INPUT_DATA_DIR/$D"
			else
				KIEKER_DIRECTORIES="$KIEKER_DIRECTORIES:$INPUT_DATA_DIR/$D"
			fi
		else
			error "$INPUT_DATA_DIR/$D is not a kieker log directory."
			exit 1
		fi
	done
fi

information "Kieker directories $KIEKER_DIRECTORIES"

#########################################
# check tools

checkExecutable privacy-analysis "${PRIVACY_ANALYSIS}"
checkDirectory input "${INPUT_DATA_DIR}"

#########################################
# run analysis

cat << EOF > privacy.config
## The name of the Kieker instance.
kieker.monitoring.name=${EXPERIMENT_ID}
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# reader
iobserve.analysis.source=org.iobserve.service.source.FileSourceCompositeStage
org.iobserve.service.source.FileSourceCompositeStage.sourceDirectories=${KIEKER_DIRECTORIES}

# data storage
iobserve.analysis.model.pcm.databaseDirectory=$DB_DIR
iobserve.analysis.model.pcm.initializationDirectory=$PCM_DIR

# privacy configuration
iobserve.analysis.privacy.alarmFile=$BASE_DIR/alarms.txt
iobserve.analysis.privacy.warningFile=$BASE_DIR/warnings.txt

iobserve.analysis.privacy.policyList=NoPersonalDataInUSAPolicy
iobserve.analysis.privacy.packagePrefix=org.iobserve.service.privacy.violation.transformation.privacycheck.policies

iobserve.analysis.privacy.probeControls=localhost:4321

EOF

export SERVICE_PRIVACY_VIOLATION_OPTS=-Dlog4j.configuration=file:///$BASE_DIR/log4j-debug.cfg
${PRIVACY_ANALYSIS} -c privacy.config

# end



