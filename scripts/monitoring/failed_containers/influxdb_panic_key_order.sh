#!/bin/bash

# Log will show e.g
# panic: keys must be added in sorted order: shard,database=varken,engine=tsm1,hostname=a85d4613ec82,id=1755,indexType=tsi1,path=/var/lib/influxdb/data/varken/varken\ 30d-1h/1755,retentionPolicy=varken\ 30d-1h,walPath=/var/lib/influxdb/wal/varkEn/varken\ 30d-1h/1755#!~#writeReqErr < shard,database=varken,engine=tsm1,hostname=a85d4613ec82,id=1755,indexType=tsi1,path=/var/lib/influxdb/data/varken/varken\ 30d-1h/1755,retentionPolicy=varken\ 30d-1h,walPath=/var/lib/influxdb/wal/varken/varken\ 30d-1h/1755#!~#writeReq

#Need to:
#- extract path=/var/lib/influxdb/data/varken/varken\ 30d-1h/1755
#- remove: /var/lib/influxdb
#    /data/varken/varken\ 30d-1h/1755
#- add: sudo rm -rf /storage/Docker/influxdb/data/data
#    sudo rm -rf /storage/Docker/influxdb/data/data/data/varken/varken\ 30d-1h/1755
#- stop container
#- Run 'rm' commands
#-restart conatiner

## Run backups to ACD encrypted volumes
    red=`tput setaf 1`
    green=`tput setaf 2`
    yellow=`tput setaf 3`
    blue=`tput setaf 4`
    magenta=`tput setaf 5`
    cyan=`tput setaf 6`
    under=`tput sgr 0 1`
    reset=`tput sgr0`


# Check running as root - attempt to restart with sudo if not already running with root
if [ $(id -u) -ne 0 ]; then tput setaf 1; echo "Not running as root, attempting to automatically restart script with root access..."; tput sgr0; echo; sudo $0 $*; exit 1; fi


# Variables
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PATH_INFLUX_HOST="/storage/Docker/influxdb/data/data"
PATH_INFLUX_INTERNAL="/storage/Docker/influxdb/data/data/data/_internal"
DOCKER_COMPOSE_FILE="/home/ryan/scripts/docker/monitoring.yml"
SERVICE_NAME="influxdb"

LOG="$WHEREAMI/error_log.txt"
LOGBEFOREPANIC="$WHEREAMI/_error_lines.tmp"

LOGRAW="$WHEREAMI/error_log_raw.txt"

# Parse (tail or cat) log for panic string
# See here if tail not ending after string found: https://superuser.com/questions/270529/monitoring-a-file-until-a-string-is-found
# grep -m 1 means grep will stop after finding first instance.
# Use below line as example for testing:
#ERROR_LINE='{"log":"panic: keys must be added in sorted order: shard,database=varken,engine=tsm1,hostname=a85d4613ec82,id=1755,indexType=tsi1,path=/var/lib/influxdb/data/varken/varken\\ 30d-1h/1755,retentionPolicy=varken\\ 30d-1h,walPath=/var/lib/influxdb/wal/varkEn/varken\\ 30d-1h/1755#!~#writeReqErr \u003c shard,database=varken,engine=tsm1,hostname=a85d4613ec82,id=1755,indexType=tsi1,path=/var/lib/influxdb/data/varken/varken\\ 30d-1h/1755,retentionPolicy=varken\\ 30d-1h,walPath=/var/lib/influxdb/wal/varken/varken\\ 30d-1h/1755#!~#writeReq\n","stream":"stderr","time":"2022-01-05T11:21:07.465157047Z"}'

# Tail works but means script has to run continually which would mean we need to add logic to restart script if it fails, after it finds an error, or if docker conatiner restarts
    #ERROR_LINE=$(sudo tail -f `docker inspect --format='{{.LogPath}}' influxdb` | grep -m 1 "panic: keys must be added in sorted order")
# Cat means the script can be run every X minutes via crontab - less complexity and the log file holds many hours of data
    #ERROR_LINE=$(sudo cat `docker inspect --format='{{.LogPath}}' influxdb` | grep -m 1 "panic: keys must be added in sorted order")
    CONTAINER_LOG=$(docker inspect --format='{{.LogPath}}' influxdb)
    ERROR_LINE=$(sudo cat "$CONTAINER_LOG" | grep -m 1 "panic: keys must be added in sorted order")

    if [[ -z $ERROR_LINE ]]; then
        echo "No error found"
        exit
    fi
    
    # Save section of log preceding panic error to file as may need to parse it if not simple error
    sudo cat "$CONTAINER_LOG" | grep -B 50 -m 1 "panic: keys must be added in sorted order" > $LOGBEFOREPANIC
    
    # LOG RAW ERRORS - USEFUL FOR TESTING?DEV
    echo "" >> $TMP_LOG_ERRORS; echo "" >> $LOGRAW
    echo "[$(date +%Y%m%d-%H%M%S)]" >> $LOGRAW
    echo "20 lines up to panic line:"
    tail -20 $LOGBEFOREPANIC >> $LOGRAW


    # If simple error with 'path' in error line then parse problem path from line
    if echo $ERROR_LINE | grep -q ',path=/'; then 
        # Process error string to get everything after 'path='
        # e.g. /var/lib/influxdb/data/varken/varken\\ 30d-1h/1755,retentionPolicy=varken\\ 30d-1h,walPath=/var/lib/influxdb/wal/varken/varken\\ 30d-1h/1755#!~#writeReq\n","stream":"stderr","time":"2022-01-05T11:21:07.465157047Z"}
            #PARSE_PATH=$(echo $ERROR_LINE | awk -F',path=' '{print $2}')
            PARSE_PATH=$(echo $ERROR_LINE | sed 's/.*,path=//')

        # Get internal container path - remove end of previously parsed string
        # e.g. /var/lib/influxdb/data/varken/varken\\ 30d-1h/1755
            #PATH_INTERNAL=$(echo $PARSE_PATH | cut -d, -f1)
            #PATH_INTERNAL=$(echo $PARSE_PATH | awk -F, '{print $1}')
            PATH_INTERNAL=$(echo $PARSE_PATH | sed 's/,.*//')

    # If not a simple error with a 'path' in error line
    else
        # Find last occurrencee of 'tsm1_file=' before panic error
        # e.g. ts=2022-02-25T14:26:44.870021Z lvl=info msg="Compacting file" log_id=0ZtKGhcl000 engine=tsm1 tsm1_level=1 tsm1_strategy=level trace_id=0ZtKHC1G000 op_name=tsm1_compact_group db_shard_id=3367 tsm1_index=7 tsm1_file=/var/lib/influxdb/data/telegraf/autogen/3367/000000279-000000001.tsm
            ERROR_LINE=$(cat $LOGBEFOREPANIC | grep "tsm1_file" | tail -1)

        # Strip off start of line to get full file causing error
        # e.g. /var/lib/influxdb/data/telegraf/autogen/3367/000000279-000000001.tsm
            PARSE_PATH=$(echo $ERROR_LINE | sed 's/.*tsm1_file=//')

        # Strip last / onwards to get internal dir path of shard to delete
        # e.g. /var/lib/influxdb/data/telegraf/autogen/3367
            PATH_INTERNAL=$(echo $PARSE_PATH | sed 's|\(.*\)/.*|\1|')
    fi


# Get ending of internal container string so that we can append to host Docker path
# e.g. /data/varken/varken\\ 30d-1h/1755
    #PARSE_PATH_HOST=$(echo $PATH_INTERNAL | awk -F'\/var\/lib\/influxdb' '{print $2}')
    PARSE_PATH_HOST1=$(echo $PATH_INTERNAL | sed 's/.*\/var\/lib\/influxdb//')

# Replace any occurances of '\\' - somehow comes before any spaces in path
# e.g. /data/varken/varken\ 30d-1h/1755
    PARSE_PATH_HOST2=$(echo $PARSE_PATH_HOST1 | sed -e 's/\\\\/\\/g')

# Add string to start of internal path substring to get host path
# e.g. /storage/Docker/influxdb/data/data/data/varken/varken\ 30d-1h/1755
    PATH_HOST="$PATH_INFLUX_HOST$PARSE_PATH_HOST2"

# Display error details
    echo "Found error in $SERVICE_NAME"
    echo "Error internal path: $PATH_INTERNAL"
    echo "Error host path: $PATH_HOST"
    echo "[$(date +%Y%m%d-%H%M%S)] Error in: $PATH_HOST" >> $LOG
    echo "[$(date +%Y%m%d-%H%M%S)] Raw Error Line: $ERROR_LINE" >> $LOG


# Stop container
    echo "Stopping container"
    docker stop $SERVICE_NAME
    docker rm -f -v $SERVICE_NAME

# Delete paths
    echo "Deleting: $PATH_HOST"
    eval sudo rm -rf "$PATH_HOST"
    echo "Deleting: $PATH_INFLUX_INTERNAL"
    eval sudo rm -rf $PATH_INFLUX_INTERNAL

# Restart container
    echo "Restarting container"
    docker compose -f $DOCKER_COMPOSE_FILE up -d --force-recreate $SERVICE_NAME

