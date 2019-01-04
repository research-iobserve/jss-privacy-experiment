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

EVAL_PERFORMANCE="$TOOLS_DIR/evaluate-jss-performance-0.0.3-SNAPSHOT/bin/evaluate-jss-performance"

checkExecutable "Performance evaluation" "${EVAL_PERFORMANCE}"

###################################

# remove all logs
#rm -rf $DATA_DIR/kieker-*

# create logs
#$BASE_DIR/execute-observation.sh

EXECUTION_DIR="${BASE_DIR}/executions"

LOOP=0

# repeat analysis
while [ "$LOOP" != "1000" ] ; do
	# execute privacy analysis
	$BASE_DIR/execute-analysis.sh "${LOOP}"

	KIEKER_BASE_DIR="${EXECUTION_DIR}/${LOOP}/privacy-result"

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
kieker.analysisteetime.plugin.reader.filesystem.LogsReaderCompositeStage.logDirectories=$KIEKER_DIR/

org.iobserve.evaluate.jss.EvaluateMain.outputFile=jss-result-$LOOP.csv
EOF
	# execute evaluation
	EVALUATE_JSS_PERFORMANCE_OPTS="-Dlog4j.configuration=file://$BASE_DIR/log4j-debug.cfg"
	${EVAL_PERFORMANCE} -c $BASE_DIR/eval.config
	LOOP=`expr $LOOP + 1`
done

# end
