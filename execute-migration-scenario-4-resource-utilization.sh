#!/bin/bash

# run the migration scenario N times.

# Parameters:
# $1 = experiment id, e.g., simulated-jpetstore-service-1

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

EXECUTION_DIR="${BASE_DIR}/executions/${EXPERIMENT_ID}"
EXECUTE_ANALYSIS="${BASE_DIR}/execute-analysis-4-resource-monitoring.sh"

###################################
# checks

checkDirectory "executions" "${EXECUTION_DIR}"
checkExecutable "execute-analysis" "${EXECUTE_ANALYSIS}"

###################################

ITERATION=1

# repeat analysis
while [ "$ITERATION" != "10" ] ; do
	if [ -d "${EXECUTION_DIR}/${ITERATION}" ] ; then
		echo "Skipping existing run $ITERATION"
	else
		# execute privacy analysis
		"${EXECUTE_ANALYSIS}" "${EXPERIMENT_ID}" "${ITERATION}"
	fi
	ITERATION=`expr $ITERATION + 1`
done

# end
