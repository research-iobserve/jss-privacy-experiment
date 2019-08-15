#!/bin/bash

# (re)run service performance result evaluation

# execute setup

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

## configuration
DATA_BASE_DIR="/data/reiner/jss-experiments/execution-2/"

checkExecutable "performance evaluation" "${EVAL_SERVICE_PERFORMANCE}"

## script

rm -f eval.log
touch eval.log

for I in `ls ${DATA_BASE_DIR}` ; do

	export EXECUTION_DIR="${DATA_BASE_DIR}/$I"

	echo "== $I =="

	ITERATION=0

	# repeat analysis
	while [ "$ITERATION" != "200" ] ; do
		echo ">> $I $ITERATION of 200"
		KIEKER_BASE_DIR="${EXECUTION_DIR}/${ITERATION}/privacy-result"
		EXECUTION_RESULTS_DIR="${EXECUTION_DIR}/${ITERATION}/performance-results"

		mkdir -p ${EXECUTION_RESULTS_DIR}

		KIEKER=`ls "${KIEKER_BASE_DIR}/"`
		KIEKER_DIR="${KIEKER_BASE_DIR}/${KIEKER}"

		# configure evaluation
		cat << EOF > $BASE_DIR/eval.config
## The name of the Kieker instance.
kieker.monitoring.name=EXP
kieker.monitoring.hostname=
kieker.monitoring.metadata=true

# file collector
kieker.tools.source=kieker.tools.source.LogsReaderCompositeStage
kieker.tools.source.LogsReaderCompositeStage.logDirectories=${KIEKER_DIR}/

org.iobserve.stages.sink.CSVFileWriter.outputFile=${EXECUTION_RESULTS_DIR}/execution-${ITERATION}.csv
EOF
		# execute evaluation
		EVALUATE_SERVICE_PERFORMANCE_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j.cfg"
		${EVAL_SERVICE_PERFORMANCE} -c $BASE_DIR/eval.config >> eval.log
		ITERATION=`expr $ITERATION + 1`

		rm $BASE_DIR/eval.config
	done
done 
# end

