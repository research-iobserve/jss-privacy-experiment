#!/bin/bash

## Read a Kieker log and compute response times.
# Requires
# - CALC_RESPONSE_TIME

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

if [ "$1" == "" ] ;then
    error "Missing data set path"
    exit
else
    MEASUREMENT_DIR="$1"
fi

###########################
# setup

checkDirectory response-time-directory "${MEASUREMENT_DIR}"

KIEKER_DIR_NAME=`ls "${MEASUREMENT_DIR}" | head -1`

KIEKER_LOG="${MEASUREMENT_DIR}/${KIEKER_DIR_NAME}/"

########################
# configure

cat << EOF > response-time.conf
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# log reader
kieker.tools.source=kieker.tools.source.LogsReaderCompositeStage
kieker.tools.source.LogsReaderCompositeStage.logDirectories=${KIEKER_LOG}
kieker.analysis.source.file.DatEventDeserializer.bufferSize=1000000
kieker.analysis.source.file.BinaryEventDeserializer.bufferSize=1000000
org.iobserve.stages.sink.CSVFileWriter.outputFile=${MEASUREMENT_DIR}/response-time.csv
EOF

information "Running ${MEASUREMENT_DIR}"

export CALCULATE_RESPONSE_TIME_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j-info.cfg"
${CALC_RESPONSE_TIME} -c response-time.conf

rm response-time.conf

# end


