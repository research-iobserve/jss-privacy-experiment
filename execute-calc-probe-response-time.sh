#!/bin/bash

## Read a Kieker log and compute probe response time.

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

##########################
# check tools
checkExecutable calc-response-time $CALC_RESPONSE_TIME

##########################
# parameter

if [ "$1" == "" ] ; then
	error "Missing model size number"
	exit
else
	RUN="$1"
fi

if [ "$2" == "" ] ;then
    error "Missing base directory for probe measurment data"
    exit
else
    MEASUREMENT_DIR="$2"
fi

###########################
# setup

PROBE_DIR="${MEASUREMENT_DIR}/$RUN/response-time/"

checkDirectory probe-directory "${PROBE_DIR}"

KIEKER_DIR_NAME=`ls "${PROBE_DIR}" | head -1`

KIEKER_LOG="${PROBE_DIR}/${KIEKER_DIR_NAME}/"

########################
# configure

cat << EOF > response-time.conf
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# file collector
kieker.tools.source=kieker.tools.source.LogsReaderCompositeStage
kieker.tools.source.LogsReaderCompositeStage.logDirectories=${KIEKER_LOG}
kieker.analysis.source.file.DatEventDeserializer.bufferSize=1000000
kieker.analysis.source.file.BinaryEventDeserializer.bufferSize=1000000
org.iobserve.stages.sink.CSVFileWriter.outputFile=${PROBE_DIR}/response-time.csv
EOF

information "Running ${PROBE_DIR}"

export CALCULATE_RESPONSE_SELENIUM_RESPONSE_TIME_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j-info.cfg"
${CALC_RESPONSE_TIME} -c response-time.conf

# end


