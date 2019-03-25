#!/bin/bash

# (re)run jss performance result evaluation

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

EVAL_PERFORMANCE="${TOOLS_DIR}/evaluate-jss-performance-0.0.3-SNAPSHOT/bin/evaluate-jss-performance"

checkExecutable "performance evaluation" "${EVAL_PERFORMANCE}"

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
iobserve.analysis.source=org.iobserve.service.source.GenericFileSourceCompositeStage
kieker.analysisteetime.plugin.reader.filesystem.LogsReaderCompositeStage.logDirectories=${KIEKER_DIR}/

org.iobserve.evaluate.jss.EvaluateMain.outputFile=${EXECUTION_RESULTS_DIR}/execution-${ITERATION}.csv
EOF
		# execute evaluation
		EVALUATE_JSS_PERFORMANCE_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j.cfg"
		${EVAL_PERFORMANCE} -c $BASE_DIR/eval.config >> eval.log
		ITERATION=`expr $ITERATION + 1`
	done
done 
# end

