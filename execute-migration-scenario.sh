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

if [ "$1" == "" ] ; then
	error "Missing experiment id"
	exit 1
else
	EXPERIMENT_ID="$1"
	information "Experiment $EXPERIMENT_ID"
fi

EVAL_PERFORMANCE="$TOOLS_DIR/evaluate-jss-performance-0.0.3-SNAPSHOT/bin/evaluate-jss-performance"

checkExecutable "Performance evaluation" "${EVAL_PERFORMANCE}"

EXECUTION_DIR="${BASE_DIR}/executions/${EXPERIMENT_ID}"

###################################

ITERATION=0

# repeat analysis
while [ "$ITERATION" != "1000" ] ; do
	information "Analysis run $ITERATION"

	# execute privacy analysis
	$BASE_DIR/execute-analysis.sh "${EXPERIMENT_ID}" "${ITERATION}"

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
iobserve.analysis.source=org.iobserve.service.source.GenericFileSourceCompositeStage
kieker.analysisteetime.plugin.reader.filesystem.LogsReaderCompositeStage.logDirectories=${KIEKER_DIR}/

org.iobserve.evaluate.jss.EvaluateMain.outputFile=${EXECUTION_RESULTS_DIR}/execution-${ITERATION}.csv
EOF
	# execute evaluation
	EVALUATE_JSS_PERFORMANCE_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg"
	${EVAL_PERFORMANCE} -c $BASE_DIR/eval.config
	ITERATION=`expr $ITERATION + 1`
done

# end
