#!/bin/bash

## Read a Kieker log and compute probe response time.
# Requires
# - CALC_RESOURCES

# parameter
# $1 = directory containing a kieker log directory

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
checkExecutable calc-resources $CALC_RESOURCES

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

checkDirectory probe-directory "${MEASUREMENT_DIR}"

KIEKER_DIR_NAME=`ls "${MEASUREMENT_DIR}" | head -1`

KIEKER_LOG="${MEASUREMENT_DIR}/${KIEKER_DIR_NAME}/"

########################
# configure

cat << EOF > resources.conf
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# file collector
kieker.tools.source=kieker.tools.source.LogsReaderCompositeStage
kieker.tools.source.LogsReaderCompositeStage.logDirectories=${KIEKER_LOG}
kieker.analysis.source.file.DatEventDeserializer.bufferSize=1000000
kieker.analysis.source.file.BinaryEventDeserializer.bufferSize=1000000
org.iobserve.stages.sink.CSVFileWriter.outputCpuUtilizationFile=${MEASUREMENT_DIR}/cpu-resources.csv
org.iobserve.stages.sink.CSVFileWriter.outputMemUtilizationFile=${MEASUREMENT_DIR}/mem-resources.csv
EOF

information "Running ${MEASUREMENT_DIR}"

export CALCULATE_RESOURCES_OPTS="-Dlog4j.configuration=file:///$BASE_DIR/log4j-info.cfg"
${CALC_RESOURCES} -c resources.conf

# end
rm resources.conf

# end
