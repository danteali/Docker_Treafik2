#!/bin/sh

# Generate text file for node exporter collector to record generic activity.
# Call with arguments:
# $1 = metric suffix ie. will be appended to 'node_' to record in Prometheus
# $2 = storage
# $3= metric e.g. 1(start)/0(stop) or 3.14 or anything

# Make sure to output to the path where NodeExporter is configured to look for files.

# Nodeexporter arguments:
# SUFFIX=$1; ACTION=$2; REMOTE=$3; METRIC=$4
# e.g. ./rclone.sh "rclone" "sync" "GCD_aabeywales_media" "1"
# e.g. ./rclone.sh "rclone" "synced_size" "GCD_aabeywales_media" "21223872314"
# Appears in prometheus as: 
# node_rclone{action="sync", remote="GCD_aabeywales_scratchpad", instance="nodeexporter:9100", job="nodeexporter"}  1
# node_rclone{action="synced_size", remote="GCD_aabeywales_media", instance="nodeexporter:9100", job="nodeexporter"}  21223872314

# Define variables
SUFFIX="rclone"
ACTION=$1
REMOTE=$2
METRIC=$3

# Specify where output file should be saved.
OUTPUTFILE=/storage/Docker/nodeexporter/textfile_collector/$SUFFIX.prom

echo "node_$SUFFIX{action=\"$ACTION\",remote=\"$REMOTE\"} $METRIC" > $OUTPUTFILE


