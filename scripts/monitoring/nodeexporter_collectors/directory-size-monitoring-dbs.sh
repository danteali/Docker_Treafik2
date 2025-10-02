#!/bin/bash

# Get various directory sizes for metrics databases
# And process 'du' output to create nicer names in prometheus metric tag.

# https://www.robustperception.io/monitoring-directory-sizes-with-the-textfile-collector

# Set temp files for working
# $$ returns current process PID, used below to create temp file.
# $(basename "$0") returns filename of this script
# If we want to be even tidier we could also remove extension with: ${FILENAME%%.*}
THISFILENAME=$(basename "$0")
TEMPFILE1="/tmp/${THISFILENAME%%.*}.$$_1"
TEMPFILE2="/tmp/${THISFILENAME%%.*}.$$_2"
DATETIME="$(date +%Y%m%d_%H%M%S)"

# Specify where output file should be saved. This should be where nodeexporter looks for the files.
OUTPUTFILE=/storage/Docker/nodeexporter/textfile_collector/directory_size_monitoring_dbs.prom

# du Binary Location
BINDU="/usr/bin/du"

# Add list of directories to be monitored. 
DIRECTORIES="/storage/Docker/influxdb/data/data/data/*
             /storage/Docker/prometheus/data/data
             /storage/Docker/victoriametrics/data/data
             /storage/Docker/mariadb/data/databases
             /storage/Docker/plex"

sudo $BINDU -sb $DIRECTORIES >> $TEMPFILE1

while IFS="" read -r line || [ -n "$line" ]
do

  size=$(printf '%s\n' "$line" | awk '{print $1}')
  directory=$(printf '%s\n' "$line" | awk '{print $2}')
  basename=$(basename $directory)

  if [[ $line = *"influx"* ]]; then
    dataset="InfluxDB"
    nicename="$basename"
  elif [[ $line = *"prometheus"* ]]; then
    dataset="Prometheus"
    nicename="All"
  elif [[ $line = *"victoriametrics"* ]]; then
    dataset="VictoriaMetrics"
    nicename="All"
  elif [[ $line = *"mariadb"* ]]; then
    dataset="MariaDB"
    nicename="All"
  elif [[ $line = *"plex"* ]]; then
    dataset="Plex"
    nicename="All"
  fi

  echo "#$DATETIME" >> $TEMPFILE2
  echo "node_directory_monitoring_dbs_size_bytes{dataset=\"$dataset\", nicename=\"$nicename\", directory=\"$directory\"} $size" >> $TEMPFILE2

done < $TEMPFILE1

mv $TEMPFILE2 $OUTPUTFILE

rm $TEMPFILE1
#rm $TEMPFILE2