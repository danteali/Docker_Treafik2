#!/bin/bash

# Example command:
# curl -G 'http://192.168.0.222:8428/api/v1/admin/tsdb/delete_series' --data-urlencode 'match[]={job="pbs"}' | jq

if [[ $* = *"--help"* ]]; then
    echo "DELETE SPECIFIC VM JOBS"
    echo "Update array inside script with job names to delete."
    echo "Run script with '--verify' flag to confirm metric existence."
    echo "Run script with '--delete' flag to perform deletion (or set variable PERFORM_DELETION=1)."
    echo
fi

# Debug just outputs some additional info while running script to help when testing
DEBUG=0

# Do deletion (vs just verifying metric existence)
PERFORM_DELETION=0
if [[ $* = *"--delete"* ]]; then
    echo "Enabling deletion..."
    PERFORM_DELETION=1
elif [[ $* = *"--verify"* ]]; then
    echo "Verifying metric existence, not deleting metrics..."
    PERFORM_DELETION=0
fi

VM_URL="http://localhost:8428"

# Period to check for data existence before deleting
# Not essential but can be insightful to verify series contains metrics.
EXISTENCE_QUERY_START="7 days ago"
#EXISTENCE_QUERY_START_ALL='1970-01-01 01:00:00'     # Zero in unix time
EXISTENCE_QUERY_START_ALL='2018-01-01'     # Before we started TSDB records
EXISTENCE_QUERY_END="now"
EXISTENCE_QUERY_STEP="1h"   # Don't really care about resolution of data queries - we're just trying to estimate number of series which will be removed so actual data point resolution not neccessary

# List series we want to delete
DELETE_THESE_JOBS=(
    healthchecks-self-hosted
)

# Indents echo'ed text if piped to this function
function indent() { sed 's/^/    /'; }

# Loop through series
for i in "${!DELETE_THESE_JOBS[@]}"; do
    DELETEME="${DELETE_THESE_JOBS[$i]}"
    
    # CREATE COMMAND - DATA EXISTENCE CHECK - COUNT SERIES TO BE DELETED
    # JOBS_FETCHED=$(curl -s -G 'http://localhost:8428/api/v1/query_range' \
    # --data-urlencode 'query=node_cpu_seconds_total' \
    # --data-urlencode 'start='$(date -d '10 min ago' +%s) \
    # --data-urlencode 'end='$(date +%s) \
    # --data-urlencode 'step=1m' | jq '[.data.result[].metric.instance] | length' )
    unset JOBS_FETCHED_CMD
    unset JOBS_FETCHED
    JOBS_FETCHED_CMD=("curl --get")
    JOBS_FETCHED_CMD+=("--silent")
    JOBS_FETCHED_CMD+=("--url '${VM_URL}/api/v1/query_range'")
    JOBS_FETCHED_CMD+=("--data-urlencode 'query={job=~\"$DELETEME\"}'")
    JOBS_FETCHED_CMD+=("--data-urlencode 'start=$(date -d "$EXISTENCE_QUERY_START" +%s)'")
    JOBS_FETCHED_CMD+=("--data-urlencode 'end=$(date -d "$EXISTENCE_QUERY_END" +%s)'")
    JOBS_FETCHED_CMD+=("--data-urlencode 'step=$EXISTENCE_QUERY_STEP'")
    JOBS_FETCHED_CMD+=("| jq '[.data.result[].metric.instance] | length'")
    # EVALUATE COMMAND
    JOBS_FETCHED=$(eval "${JOBS_FETCHED_CMD[@]}")
    # NOTIFY USER
    echo; echo "Pre-Deletion Series Count ..."
    echo "Job: $DELETEME" | indent
    echo "Query Period: $EXISTENCE_QUERY_START -> $EXISTENCE_QUERY_END (Step size: $EXISTENCE_QUERY_STEP)" | indent
    echo "JOB METRICS FETCHED IN QUERY PERIOD: $JOBS_FETCHED" | indent
    
    if [[ ${PERFORM_DELETION} -eq 0 ]]; then
        echo "Deletion not requested, exiting script after verifying metric existence"
        exit 0
    fi

    # CREATE COMMAND - DELETE SERIEES
    # curl -X POST 'http://localhost:8428/api/v1/admin/tsdb/delete_series'
    #    --data-urlencode 'match[]={job="frigate-exporter-prometheus"}'
    unset DELETE_JOBS_CMD
    DELETE_JOBS_CMD=("curl -X POST '${VM_URL}/api/v1/admin/tsdb/delete_series'")
    DELETE_JOBS_CMD+=("--silent")
    DELETE_JOBS_CMD+=("--data-urlencode 'match[]={job=~\"$DELETEME\"}'")
    # DISPLAY COMMAND
    echo; echo "Deleting series with command:"
    echo "${DELETE_JOBS_CMD[*]}" | indent
    # RUN COMMAND
    eval "${DELETE_JOBS_CMD[@]}"

    # RE-CHECK DATA EXISTENCE - COUNT SERIES
    # EVALUATE COMMAND
    unset JOBS_FETCHED
    JOBS_FETCHED=$(eval "${JOBS_FETCHED_CMD[@]}")
    # NOTFY USER
    echo; echo "Verifying data no longer exists ..."
    echo " - Deletion of data may take some time so may not have been fully actioned yet." | indent
    echo " - Using same query and timescales as pre-deletion check." | indent
    echo "JOB METRICS FETCHED IN QUERY PERIOD: $JOBS_FETCHED" | indent

    echo; echo "======================================================================================================"

    #exit
done

