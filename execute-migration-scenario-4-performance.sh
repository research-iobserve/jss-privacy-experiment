#!/bin/bash

# Run the performance experiment 200 times and calculate the
# response times.

# parameter
# $1 = experiment id

BASE_DIR=$(cd "$(dirname "$0")"; pwd)

if [ -f $BASE_DIR/config ] ; then
	. $BASE_DIR/config
else
	echo "Missing configuration"
	exit 1
fi

. $BASE_DIR/common-functions.sh

if [ "$1" == "" ] ; then
	error "Missing experiment id"
	exit 1
else
	EXPERIMENT_ID="$1"
	information "Experiment $EXPERIMENT_ID"
fi

checkExecutable "Performance evaluation" "${EVAL_SERVICE_PERFORMANCE}"

EXECUTION_DIR="${BASE_DIR}/executions/${EXPERIMENT_ID}"

###################################

ITERATION=0

# repeat analysis
while [ "$ITERATION" != "200" ] ; do
	if [ -d "${EXECUTION_DIR}/${ITERATION}" ] ; then
		echo "Skipping existing run $ITERATION"
	else
		# execute privacy analysis
		$BASE_DIR/execute-analysis-4-performance-monitoring.sh "${EXPERIMENT_ID}" "${ITERATION}"

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
		EVALUATE_SERVICE_PERFORMANCE_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg"
		${EVAL_SERVICE_PERFORMANCE} -c $BASE_DIR/eval.config

		rm $BASE_DIR/eval.config
	fi
	ITERATION=`expr $ITERATION + 1`
done

# end
