#!/bin/bash
    red=`tput setaf 1`
    green=`tput setaf 2`
    yellow=`tput setaf 3`
    blue=`tput setaf 4`
    magenta=`tput setaf 5`
    cyan=`tput setaf 6`
    under=`tput sgr 0 1`
    reset=`tput sgr0`


# =======================================================================================================================
# TODO
# 1. NOT IMPLEMENTED OPTION TO WATCH ALL CONTAINERS YET !!!!
# 2. Enable functionality to exclude specific containers if watching all
# =======================================================================================================================




# =======================================================================================================================
# FUNCTIONALITY
# =======================================================================================================================
#
# This script either:
# 1. WATCHES DEFINED SET OF CONTAINERS
#     Define set of containers in WATCHLIST_FILE. Script will alert if any are not running. 
#     Set variable WATCHALL=0 and define a WATCHLIST_FILE below
#
# 2. WATCHES ALL CONTAINERS
#     If script sees a container it will watch it and subsequently alert if it stops running.
#     Set variable WATCHALL=1
#
#
# - If a container is not running...
#
#     > 1ST OCCURANCE:
#       The first time a container is identified as stopped/missing by this script it will be logged in the
#       FIRST_WARN_FILE to give a grace period in case a container is updating or restarting.
#
#     > 2ND OCCURANCE:
#       If it is still not running in the next check then an alert will be sent. Therefore it takes two 
#       executions of this script to send out an alert so this needs to be taken into account when setting
#       the script run interval in crontab.
#
# - Only one alert will be sent to avoid bombarding with alerts.
# 
# - Optionally enable notifications if container comes back up (variable: ).
#
#
# You should set this script to be run my crontab on the frequency that you need. 
#     e.g. Run every 10m:
#          0,10,20,30,40,50 * * * * /path/to/script/crontab_monitor.sh      # Monitor for failed docker containers
#     e.g. Run every 5m:
#          */5 * * * /path/to/script/crontab_monitor.sh      # Monitor for failed docker containers
#
# =======================================================================================================================



# Check running as root - attempt to restart with sudo if not already running with root
    if [ $(id -u) -ne 0 ]; then tput setaf 1; echo "Not running as root, attempting to automatically restart script with root access..."; tput sgr0; echo; sudo $0 $*; exit 1; fi




# =======================================================================================================================
# INITIALISE VARIABLES ETC
# =======================================================================================================================

    # Don't edit WHEREAMI, it needs to be at the top since other vars use it.
    WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    # ----------------------------------------------------------------
    # GET SENSITIVE INFO FROM .CONF FILE
    # - Set email address for notifications
   
    # Add any variables to a crontab_monitor.conf file in the same dir as this script. The conf 
    # file does not need to have quotes around the variables and must have an empoty line at the end.
    CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    typeset -A secrets    # Define array to hold variables 
    while read line; do
      if echo $line | grep -F = &>/dev/null; then
        varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
      fi
    done < $CONF_DIR/crontab_monitor.conf
    #echo ${secrets[EMAIL_ADDRESS]}
    EMAIL_ADDRESS="${secrets[EMAIL_ADDRESS]}"
    # ----------------------------------------------------------------



    # ----------------------------------------------------------------
    # USER VARIABLES - CHANGE THESE TO CUSTOMISE FUNCTIONALITY
    # ----------------------------------------------------------------

    # Print debug messages?
    DEBUG=1
    
    # Set path to email binary if you want to send email notifications.
    # You should have configured the ability to send email separately and confirmed it works.
    MAIL_BIN="/usr/bin/mutt"
    
    # Snapraid - only needed if you are using Snapraid and snapraid pauses some containers while it 
    # runs. We will check whether snapraid is running and ignore the paused/stopped status of any
    # containers which have been paused/stopped by snapraid so that we don't trigger warnings for
    # intentional pauses. Leave the empty if you don't use snapraid.
    #SNAPRAID_SCRIPT="/home/ryan/scripts/snapraid/snapraid_script"
    SNAPRAID_SCRIPT="/home/ryan/scripts/snapraid-aio/script-config.sh"

    # Files - create these before first use in the same directory as this script.
    LOG_EXISTING_ALERTS="$WHEREAMI/crontab_monitor.alerts"
    LOG_FIRST_WARN="$WHEREAMI/crontab_monitor.warn"
    LOG_ALERT_HISTORY="$WHEREAMI/crontab_monitor.history"
    
    
    # WATCHALL FUNCTIONALITY NOT ENABLED YET
    # Watch all containers and warn if any stop?
    # If set to '0' will only watch those containers defined in the WATCHLIST_FILE
    WATCHALL=0

    # This file should list all the containers you wish to monitor
    WATCHLIST_FILE="$WHEREAMI/crontab_monitor.watchlist"
    
    # Notification Switches - set 0/1 depending on which alerts you want to send.
    # Notify on screen
      SCREEN=1
        
    # APPLIES TO NON-EMAIL NOTIFICATION SERVICES - Send combined alert for all containers which have gone down/up
      NOTIFY_SUMMARY=1
    # APPLIES TO NON-EMAIL NOTIFICATION SERVICES - Send individual alert for each container which goes down/up.
      NOTIFY_EVERY_INSTANCE=0
    
    # APPLIES TO ALL NOTIFICATION ROUTES - Notify on container restoration as well as failure?
      NOTIFY_ON_RESTORE=1

    # Send Pushbullet alerts - this calls my Pushbullet script which can be found here:
    # https://github.com/danteali/Pushbullet
      NOTIFY_PB=0
    # Send Pushover alerts - this calls my Pushover script which can be found here:
    # https://github.com/danteali/Pushover
      NOTIFY_PO=1
      NOTIFY_PO_CHANNEL="alert"
    # Send Slack alerts - this calls my Slack script which can be found here:
    # https://github.com/danteali/Slackomatic
      NOTIFY_SLACK=1
      NOTIFY_SLACK_USER="docker-crontab-monitor" # 'Sender' to appear in slack notification
      NOTIFY_SLACK_CHANNEL="#alert"
      NOTIFY_SLACK_ICON=":whale:"
      
    # Traeting email separately from other notification services since we want separate control over whether we send summary/individual
    # service notifications to email. Most other services (e.g. PushOver, Slack) ave a much higher limit on number of notifications sent per day.
    # In addition we don't want to clog up inboxes needlessly.
      NOTIFY_EMAIL_INSTANCES=0      # This is independant of NOTIFY_EVERY_INSTANCE=1 being set
      NOTIFY_EMAIL_SUMMARY=1        # This is independant of NOTIFY_SUMMARY=1 being set


    # Update NodeExporter (used to push data into Prometheus for display in Grafana)
      NOTIFY_NODEEXPORTER=0
      NODEEXPORTER_PATH=/storage/Docker/nodeexporter/textfile_collector/docker_container_down.prom
      # Previously used custom logging script (from here: https://github.com/danteali/docker_cron_monitor/blob/master/nodeexporter.sh)
      # But moved to directly writing metric file since likely NodeExporter would miss some updates if multiple containers status changed at once.
      #NODEEXPORTER_SCRIPT_PATH="/home/ryan/scripts/docker/scripts/monitoring/nodeexporter_collectors/logger.sh"

    # Update VictoriaMetrics 
      NOTIFY_VICTORIAMETRICS=1
      NOTIFY_VICTORIAMETRICS_HOST="http://192.168.0.222:8428"
      # Initially considered custom vmimport.sh helper script (/home/ryan/scripts/victoriametrics-imports/vm-import.sh)
      # But moved to directly writing metrics since easier to process as/when needed instead of managing file contents.
      #VICTORIAMETRICS_PATH="/tmp/metrics/crontab-monitor.prom"
      #VICTORIAMETRICS_SCRIPT="/home/ryan/scripts/victoriametrics-imports/vm-import.sh"

    
    # ----------------------------------------------------------------
    # SCRIPT VARIABLES - NO NEED TO CHANGE ANY OF THESE
    # ----------------------------------------------------------------

    WHOAMI=$(basename $0)
    DATETIME=$(date +%Y%m%d-%H%M%S)
    #
    WATCHLIST=()
    #
    EXISTING_ALERT_FILE_ARRAY=()
    EXISTING_ALERT_FILE_LIST=""
    #
    FIRST_WARN_FILE_ARRAY=()
    FIRST_WARN_FILE_LIST=""
    #
    SNAPRAID_PS=""
    SNAPRAID_STATUS="Stopped"
    SNAPRAID_SERVICES=""
    SNAPRAID_SERVICES_ARRAY=()
    #
    CONTAINER_STATUS_ARRAY=()
    CONTAINER_EXISTING_ALERT_FILE_ARRAY=()
    CONTAINER_PREV_WARN_ARRAY=()
    CONTAINER_NOT_RUNNING_ARRAY=()
    #
    NEW_ALERTS_ARRAY=()
    NEW_ALERTS_STRING=""
    NEW_ALERTS=0
    NEW_WARNINGS_ARRAY=()
    NEW_WARNINGS_STRING=""
    NEW_WARNINGS=0
    CLEARED_WARNINGS_ARRAY=()
    CLEARED_WARNINGS_STRING=""
    CLEARED_WARNINGS=0
    CLEARED_ALERTS_ARRAY=()
    CLEARED_ALERTS_STRING=""
    CLEARED_ALERTS=0
    CONTINUING_ALERTS_ARRAY=()
    CONTINUING_ALERTS_STRING=""
    CONTINUING_ALERTS=0
    

# =======================================================================================================================
# DEBUGGING FUNCTION TO OUTPUT ARRAY DETAILS
# =======================================================================================================================
function debug_array () {
    if [[ $DEBUG == 1 ]]; then
        DEBUG_ARRAY=("$@")
        echo "+++++ DEBUGGING - ARRAY DETAILS ++++++++++++++++++++++++++++++++++++++++++"
        echo -e "\tARRAY LENGTH = "${#DEBUG_ARRAY[@]}
        echo -e "\tARRAY ELEMENTS..."
        #All elements on single line
        #echo ${DEBUG_ARRAY[@]}
        #All elements on new lines:
        printf "\t\t%s\n" "${DEBUG_ARRAY[@]}"
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo
    fi
}


# ======================================================================================================================================
# IMPORT WATCH LIST
# ======================================================================================================================================

# Read in watchlist
  # Option 1:
    #IFS=$'\n' read -d '' -r -a WATCHLIST < $WATCHLIST_FILE
  # Option 2:
    #IFS=$'\r\n' GLOBIGNORE='*' command eval  'WATCHLIST=($(cat $WATCHLIST_FILE))'
  # Option 3:
    readarray -t WATCHLIST < $WATCHLIST_FILE


# DEBUG
if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: WATCHLIST"; debug_array "${WATCHLIST[@]}"; fi



# ======================================================================================================================================
# IMPORT EXISTING ALERTS
# ======================================================================================================================================

# Read list of containers with existing alerts so that we don't repeatedly warn
# cat alerts file | grep: remove header line | awk: get column with container names
#EXISTING_ALERT_FILE_LIST=$( \
#    cat "${LOG_EXISTING_ALERTS}" \
#    | grep -v "Date" \
#    | grep -v "\-\-\-\-\-" \
#    | awk '{ print $2 }' \
#     )
# Create existing alert array
#read -r -a EXISTING_ALERT_FILE_ARRAY <<< $EXISTING_ALERT_FILE_LIST

while read line; do 
    if [[ $line != *"Date"* && $line != *"-------"* ]]; then 
        line_parsed=$(echo $line | awk '{ print $2 }'); 
        EXISTING_ALERT_FILE_ARRAY+=("$line_parsed"); 
    fi; 
done < "${LOG_EXISTING_ALERTS}"
EXISTING_ALERT_FILE_LIST="$( echo ${EXISTING_ALERT_FILE_ARRAY[@]} )"

# DEBUG
if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: EXISTING_ALERT_FILE_ARRAY"; debug_array "${EXISTING_ALERT_FILE_ARRAY[@]}"; fi



# Get existing alert start date/time so that we can report on duration of resolved alert later
# cat alerts file | grep: remove header line | awk: get column with container names
#EXISTING_ALERT_START_LIST=$( \
#    cat "${LOG_EXISTING_ALERTS}" \
#    | grep -v "Date" \
#    | grep -v "\-\-\-\-\-" \
#    | awk '{ print $1 }' \
#     )
# Create existing alert array
#read -r -a EXISTING_ALERT_START_ARRAY <<< $EXISTING_ALERT_START_LIST

while read line; do 
    if [[ $line != *"Date"* && $line != *"-------"* ]]; then 
        line_parsed=$(echo $line | awk '{ print $1 }'); 
        EXISTING_ALERT_START_ARRAY+=("$line_parsed"); 
    fi; 
done < "${LOG_EXISTING_ALERTS}"
EXISTING_ALERT_START_LIST="$( echo ${EXISTING_ALERT_START_ARRAY[@]} )"

# DEBUG
if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: EXISTING_ALERT_START_ARRAY"; debug_array "${EXISTING_ALERT_START_ARRAY[@]}"; fi



# Convert dates into epoch seconds
#date --date="$(echo "20190419-203002" | sed 's/^\(.\{13\}\)/\1:/' | sed 's/^\(.\{11\}\)/\1:/' | sed 's/-/ /')" +%s
for i in "${!EXISTING_ALERT_START_ARRAY[@]}"; do
    ALERT_SECS=$(date --date="$(echo "${EXISTING_ALERT_START_ARRAY[i]}" | sed 's/^\(.\{13\}\)/\1:/' | sed 's/^\(.\{11\}\)/\1:/' | sed 's/-/ /')" +%s)
    EXISTING_ALERT_START_SECS_ARRAY+=("$ALERT_SECS")
done

# DEBUG
if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: EXISTING_ALERT_START_SECS_ARRAY"; debug_array "${EXISTING_ALERT_START_SECS_ARRAY[@]}"; fi




# ======================================================================================================================================
# PREVIOUS FIRST WARNINGS
# ======================================================================================================================================

# Read list of containers with existing alerts so that we don't repeatedly warn
# cat alerts file | grep: remove header line | awk: get column with container names
#FIRST_WARN_FILE_LIST=$( \
#    cat "${LOG_FIRST_WARN}" \
#    | grep -v "Date" \
#    | grep -v "\-\-\-\-\-" \
#    | awk '{ print $2 }' \
#     )
# Create existing alert array
#read -r -a FIRST_WARN_FILE_ARRAY <<< $FIRST_WARN_FILE_LIST

while read line; do 
    if [[ $line != *"Date"* && $line != *"-------"* ]]; then 
        line_parsed=$(echo $line | awk '{ print $2 }'); 
        FIRST_WARN_FILE_ARRAY+=("$line_parsed"); 
    fi; 
done < "${LOG_FIRST_WARN}"
FIRST_WARN_FILE_LIST="$( echo ${FIRST_WARN_FILE_ARRAY[@]} )"

# DEBUG
if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: FIRST_WARN_FILE_ARRAY"; debug_array "${FIRST_WARN_FILE_ARRAY[@]}"; fi



# ======================================================================================================================================
# SNAPRAID
# ======================================================================================================================================
# This section will only be executed snapraid is actually running. This will look in the snapraid_script set in the variables above to 
# find the containers paused/stopped by snapraid and will exclude them from the watchlist so that we don't alert on intentionally 
# stopped scripts.
# If you don't use snapraid this section will be bypassed transparently.

# If snapraid is running then exclude the containers which snapraid pauses from our watchlist
# Check if snapraid running
    SNAPRAID_PS=$(sudo ps -eo pid,etimes,etime,command | grep -e snapraid | grep -v "grep" | grep -v "SCREEN")
    if [[ ! "$SNAPRAID_PS" == "" ]]; then
        # Set status variable for printing in log
            SNAPRAID_STATUS="Running"
        # Get docker container list from snapraid script
            SNAPRAID_SERVICES=$(grep "SERVICES='" $SNAPRAID_SCRIPT | grep -v "#" | sed -e "s/^  SERVICES='//" -e "s/'$//" | sed -e "s/^SERVICES='//" -e "s/'$//")
        # Create new array from snapraid docker container list
            read -r -a SNAPRAID_SERVICES_ARRAY <<< "$SNAPRAID_SERVICES"

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: SNAPRAID_SERVICES_ARRAY"; debug_array "${SNAPRAID_SERVICES_ARRAY[@]}"; fi



        # Create new array by looping through watchlist and excluding anything in snapraid list
        # We have to use this method since just removing elements from watchlist leaves empty spaces and retains same # of array elements
        # If we have empty elements in watchlist then later 'docker inspect' will throw up errors if run against empty string.
        # We could check later for empty elements in watchlist before running 'docker inspect' but I like a clean array.
            for i in "${!WATCHLIST[@]}"; do
                SNAPRAID_MATCH=0
                for j in "${!SNAPRAID_SERVICES_ARRAY[@]}"; do
                    # loop through snapraid array and if it matches watchlist then set flag
                    if [[ "${WATCHLIST[i]}" == "${SNAPRAID_SERVICES_ARRAY[j]}" ]]; then
                        SNAPRAID_MATCH=1
                    fi
                done
                # if flag not set (no match between watchlist & snapraid) then add element to new array
                if [[ $SNAPRAID_MATCH == 0 ]]; then
                    TEMP_ARRAY+=("${WATCHLIST[i]}")
                fi
            done

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: TEMP_ARRAY"; debug_array "${TEMP_ARRAY[@]}"; fi



       # Set watchlist to equal temp array and delete temp array
            WATCHLIST=("${TEMP_ARRAY[@]}")
            unset TEMP_ARRAY

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: WATCHLIST"; debug_array "${WATCHLIST[@]}"; fi



    fi



# ======================================================================================================================================
# QUERY DOCKER
# ======================================================================================================================================

# Loop through docker watchlist and check status, also check if alert already exists
for i in "${!WATCHLIST[@]}"; do
    CONTAINER_STATUS=""

    # INSPECT CONTAINER
    # If container not running we get an error with inspect command so can't just set CONTAINER_STATUS
    # to command result since error isn't counted as valid result.
    # Therefore need to check if command runs successfully first, then set variable.
    if (docker inspect --format='{{ .State.Status }}' "${WATCHLIST[i]}" > /dev/null 2>&1 ); then
        CONTAINER_STATUS=$(docker inspect --format='{{ .State.Status }}' "${WATCHLIST[i]}" )
    else
        CONTAINER_STATUS="NOT RUNNING"
    fi

    # Add CONTAINER_STATUS to array
    CONTAINER_STATUS_ARRAY+=("$CONTAINER_STATUS")

    # Check if new alert or if already in existing alert list
    CONTAINER_EXISTING_ALERT="no"
    if [[ $EXISTING_ALERT_FILE_LIST == *"${WATCHLIST[i]}"* ]]; then
        CONTAINER_EXISTING_ALERT="YES"
    fi
    # Add existing alert info to array
    CONTAINER_EXISTING_ALERT_FILE_ARRAY+=($CONTAINER_EXISTING_ALERT)

    # Check if alert in previously first warned list
    CONTAINER_PREV_WARN="no"
    if [[ $FIRST_WARN_FILE_LIST == *"${WATCHLIST[i]}"* ]]; then
        CONTAINER_PREV_WARN="YES"
    fi
    # Add existing alert info to array
    CONTAINER_PREV_WARN_ARRAY+=($CONTAINER_PREV_WARN)

    # Increment counts
    CONTAINERS_CHECKED=$(($CONTAINERS_CHECKED + 1))
    if [[ $CONTAINER_STATUS == "running" || $CONTAINER_STATUS == "exited" ]]; then
        # Increment count
        CONTAINERS_RUNNING=$(($CONTAINERS_RUNNING + 1))
    else
        # Increment count
        CONTAINERS_NOT_RUNNING=$(($CONTAINERS_NOT_RUNNING + 1))
        # Add non-running containers to array for checking later
        CONTAINER_NOT_RUNNING_ARRAY+=("${WATCHLIST[i]}")
    fi

done


        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTAINER_STATUS_ARRAY"; debug_array "${CONTAINER_STATUS_ARRAY[@]}"; fi

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTAINER_EXISTING_ALERT_FILE_ARRAY"; debug_array "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[@]}"; fi

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTAINER_PREV_WARN_ARRAY"; debug_array "${CONTAINER_PREV_WARN_ARRAY[@]}"; fi

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTAINER_NOT_RUNNING_ARRAY"; debug_array "${CONTAINER_NOT_RUNNING_ARRAY[@]}"; fi



# ======================================================================================================================================
# ANALYSIS
# ======================================================================================================================================

# Compare CONTAINER_NOT_RUNNING_ARRAY to FIRST_WARN_FILE_ARRAY to find any NEW_ALERTS and NEW_WARNINGS
# Loop through containers not running
for i in "${!CONTAINER_NOT_RUNNING_ARRAY[@]}"; do
    # Check to see if CONTAINERS_NOT_RUNNING element is in FIRST_WARN_FILE_ARRAY = new alert to be sent
    if [[ ${FIRST_WARN_FILE_ARRAY[@]} == *"${CONTAINER_NOT_RUNNING_ARRAY[i]}"* ]]; then
        # Increment new alert count
        NEW_ALERTS=$(($NEW_ALERTS + 1))
        # Add new alerts to array
        NEW_ALERTS_ARRAY+=("${CONTAINER_NOT_RUNNING_ARRAY[i]}")
        # Add new alerts to string
        if [[ $NEW_ALERTS == 1 ]]; then
            NEW_ALERTS_STRING=$(echo "${CONTAINER_NOT_RUNNING_ARRAY[i]}")
        else
            NEW_ALERTS_STRING=$(echo "$NEW_ALERTS_STRING, ${CONTAINER_NOT_RUNNING_ARRAY[i]}")
        fi
    # If CONTAINERS_NOT_RUNNING element is NOT in FIRST_WARN_FILE_ARRAY
    # Then check to see if it's NOT in EXISTING_ALERT_FILE_ARRAY = NEW_WARNINGS to be added to .warn file
    else
        if [[ ! ${EXISTING_ALERT_FILE_ARRAY[@]} == *"${CONTAINER_NOT_RUNNING_ARRAY[i]}"* ]]; then
            # Increment count
            NEW_WARNINGS=$(($NEW_WARNINGS + 1))
            # Add new alerts to array
            NEW_WARNINGS_ARRAY+=("${CONTAINER_NOT_RUNNING_ARRAY[i]}")
            # Add new alerts to string
            if [[ $NEW_WARNINGS == 1 ]]; then
                NEW_WARNINGS_STRING=$(echo "${CONTAINER_NOT_RUNNING_ARRAY[i]}")
            else
                NEW_WARNINGS_STRING=$(echo "$NEW_WARNINGS_STRING, ${CONTAINER_NOT_RUNNING_ARRAY[i]}")
            fi
        fi

    fi
done

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: NEW_ALERTS_ARRAY"; debug_array "${NEW_ALERTS_ARRAY[@]}"; fi
        if [[ $DEBUG == 1 ]]; then echo -e "\tSTRING: NEW_ALERTS_STRING"; echo -e "\t $NEW_ALERTS_STRING"; fi

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: NEW_WARNINGS_ARRAY"; debug_array "${NEW_WARNINGS_ARRAY[@]}"; fi
        if [[ $DEBUG == 1 ]]; then echo -e "\tSTRING: NEW_WARNINGS_STRING"; echo -e "\t $NEW_WARNINGS_STRING"; fi



# Compare FIRST_WARN_FILE_ARRAY to CONTAINER_NOT_RUNNING_ARRAY to find any CLEARED_WARNINGS
# Loop through first warnings
for i in "${!FIRST_WARN_FILE_ARRAY[@]}"; do
    # Check to see if prev warning is NOT in CONTAINERS_NOT_RUNNING list = CLEARED_WARNINGS
    if [[ ! ${CONTAINER_NOT_RUNNING_ARRAY[@]} == *"${FIRST_WARN_FILE_ARRAY[i]}"* ]]; then
        # Increment new alert count
        CLEARED_WARNINGS=$(($CLEARED_WARNINGS + 1))
        # Add new alerts to array
        CLEARED_WARNINGS_ARRAY+=("${FIRST_WARN_FILE_ARRAY[i]}")
        # Add new alerts to string
        if [[ $CLEARED_WARNINGS == 1 ]]; then
            CLEARED_WARNINGS_STRING=$(echo "${FIRST_WARN_FILE_ARRAY[i]}")
        else
            CLEARED_WARNINGS_STRING=$(echo "$CLEARED_WARNINGS_STRING, ${FIRST_WARN_FILE_ARRAY[i]}")
        fi
    fi
done

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CLEARED_WARNINGS_ARRAY"; debug_array "${CLEARED_WARNINGS_ARRAY[@]}"; fi
        if [[ $DEBUG == 1 ]]; then echo -e "\tSTRING: CLEARED_WARNINGS_STRING"; echo -e "\t $CLEARED_WARNINGS_STRING"; fi



# Compare EXISTING_ALERT_FILE_ARRAY to CONTAINER_NOT_RUNNING_ARRAY to find CLEARED_ALERTS and CONTINUING_ALERTS
# Loop through existing alerts
for i in "${!EXISTING_ALERT_FILE_ARRAY[@]}"; do
    # Check to see if existing alert element is NOT in CONTAINERS_NOT_RUNNING list = CLEARED_ALERTS
    if [[ ! ${CONTAINER_NOT_RUNNING_ARRAY[@]} == *"${EXISTING_ALERT_FILE_ARRAY[i]}"* ]]; then
        CLEARED_ALERTS=$(($CLEARED_ALERTS + 1))
        CLEARED_ALERTS_ARRAY+=("${EXISTING_ALERT_FILE_ARRAY[i]}")
        # Add cleared alerts to string
        if [[ $CLEARED_ALERTS == 1 ]]; then
            CLEARED_ALERTS_STRING=$(echo "${EXISTING_ALERT_FILE_ARRAY[i]}")
        else
            CLEARED_ALERTS_STRING=$(echo "$CLEARED_ALERTS_STRING, ${EXISTING_ALERT_FILE_ARRAY[i]}")
        fi
        # Calc time since alert raised
        NOW_SECS=$(date +%s)
        ELAPSED=$(($NOW_SECS - ${EXISTING_ALERT_START_SECS_ARRAY[i]}))
        CLEARED_ALERTS_DURATION_SECS_ARRAY+=($ELAPSED)
        ELAPSED_PRETTY="$(($ELAPSED / 86400))days $(($ELAPSED / 3600))hrs $((($ELAPSED / 60) % 60))min $(($ELAPSED % 60))sec"
        CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY+=("$ELAPSED_PRETTY")
    # Check to see if existing alert element is in CONTAINERS_NOT_RUNNING list = CONTINUING_ALERTS
    else
        CONTINUING_ALERTS=$(($CONTINUING_ALERTS + 1))
        CONTINUING_ALERTS_ARRAY+=("${EXISTING_ALERT_FILE_ARRAY[i]}")
        # Add cleared alerts to string
        if [[ $CONTINUING_ALERTS == 1 ]]; then
            CONTINUING_ALERTS_STRING=$(echo "${EXISTING_ALERT_FILE_ARRAY[i]}")
        else
            CONTINUING_ALERTS_STRING=$(echo "$CONTINUING_ALERTS_STRING, ${EXISTING_ALERT_FILE_ARRAY[i]}")
        fi
        # Record CONTINUING_ALERTS start datetime from alert file
        CONTINUING_ALERTS_START_ARRAY+=("${EXISTING_ALERT_START_ARRAY[i]}")
        # Calc time since alert raised
        NOW_SECS=$(date +%s)
        ELAPSED=$(($NOW_SECS - ${EXISTING_ALERT_START_SECS_ARRAY[i]}))
        CONTINUING_ALERTS_DURATION_SECS_ARRAY+=($ELAPSED)
        ELAPSED_PRETTY="$(($ELAPSED / 86400))days $(($ELAPSED / 3600))hrs $((($ELAPSED / 60) % 60))min $(($ELAPSED % 60))sec"
        CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY+=("$ELAPSED_PRETTY")
    fi
done

        # DEBUG
        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CLEARED_ALERTS_ARRAY"; debug_array "${CLEARED_ALERTS_ARRAY[@]}"; fi
        if [[ $DEBUG == 1 ]]; then echo -e "\tSTRING: CLEARED_ALERTS_STRING"; echo -e "\t $CLEARED_ALERTS_STRING"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CLEARED_ALERTS_DURATION_SECS_ARRAY"; debug_array "${CLEARED_ALERTS_DURATION_SECS_ARRAY[@]}"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY"; debug_array "${CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY[@]}"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTINUING_ALERTS_ARRAY"; debug_array "${CONTINUING_ALERTS_ARRAY[@]}"; fi
        if [[ $DEBUG == 1 ]]; then echo -e "\tSTRING: CONTINUING_ALERTS_STRING"; echo -e "\t $CONTINUING_ALERTS_STRING"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTINUING_ALERTS_START_ARRAY"; debug_array "${CONTINUING_ALERTS_START_ARRAY[@]}"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTINUING_ALERTS_DURATION_SECS_ARRAY"; debug_array "${CONTINUING_ALERTS_DURATION_SECS_ARRAY[@]}"; fi

        if [[ $DEBUG == 1 ]]; then echo -e "\tARRAY DEFINED: CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY"; debug_array "${CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY[@]}"; fi



# ======================================================================================================================================
# OUTPUT
# ======================================================================================================================================

# Output results to screen (if flag set)
if [[ $SCREEN == 1 ]]; then
    printf "${cyan}%40s %16s %16s %16s${reset}\n" "Container" "Status" "Already Alerted?" "Prev Warn?"
    printf "${cyan}%40s %16s %16s %16s${reset}\n" "========================================" "================" "================" "================"
    for i in "${!WATCHLIST[@]}"; do
        # if not running and no prev warning or alert = new warning = yellow
        # if not running and prev warning but not yet alerted = new alert = red
        # if not running and already alerted = existing alert = magenta
        if [[ ! "${CONTAINER_STATUS_ARRAY[i]}" == "running" ]] && [[ ! "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" == "YES" ]] && [[ ! "${CONTAINER_PREV_WARN_ARRAY[i]}" == "YES" ]]; then
            printf "${yellow}%40s %16s %16s %16s${reset}\n" "${WATCHLIST[i]}" "${CONTAINER_STATUS_ARRAY[i]}" "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" "${CONTAINER_PREV_WARN_ARRAY[i]}"
        elif [[ ! "${CONTAINER_STATUS_ARRAY[i]}" == "running" ]] && [[ ! "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" == "YES" ]] && [[ "${CONTAINER_PREV_WARN_ARRAY[i]}" == "YES" ]]; then
            printf "${red}%40s %16s %16s %16s${reset}\n" "${WATCHLIST[i]}" "${CONTAINER_STATUS_ARRAY[i]}" "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" "${CONTAINER_PREV_WARN_ARRAY[i]}"
        elif [[ ! "${CONTAINER_STATUS_ARRAY[i]}" == "running" ]] && [[ "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" == "YES" ]]; then
            printf "${magenta}%40s %16s %16s %16s${reset}\n" "${WATCHLIST[i]}" "${CONTAINER_STATUS_ARRAY[i]}" "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" "${CONTAINER_PREV_WARN_ARRAY[i]}"
        else
            printf "${green}%40s %16s %16s %16s${reset}\n" "${WATCHLIST[i]}" "${CONTAINER_STATUS_ARRAY[i]}" "${CONTAINER_EXISTING_ALERT_FILE_ARRAY[i]}" "${CONTAINER_PREV_WARN_ARRAY[i]}"
        fi
    done
    printf "${cyan}%40s %16s %16s %16s${reset}\n" "========================================" "================" "================" "================"

    # Print prev warnings list
    echo; echo "PREVIOUS WARNINGS - CONTAINER STILL DOWN -> NEW ALERTS - NOTIFICATION SENT..."
    for i in "${!NEW_ALERTS_ARRAY[@]}"; do
        echo "${NEW_ALERTS_ARRAY[i]}"
    done
    echo
    # Print previous warnings now cleared
    echo "PREVIOUS WARNINGS - CONTAINER NOW RUNNING -> WARNING CLEARED..."
    for i in "${!CLEARED_WARNINGS_ARRAY[@]}"; do
        echo "${CLEARED_WARNINGS_ARRAY[i]}"
    done
    echo
    # Print new warnings
    echo "CONTAINERS NOT RUNNING -> NEW WARNING LOGGED..."
    for i in "${!NEW_WARNINGS_ARRAY[@]}"; do
        echo "${NEW_WARNINGS_ARRAY[i]}"
    done
    echo
    # Print previous alerts now cleared
    echo "PREVIOUSLY ALERTED - CONTAINER NOW RUNNING -> ALERT CLEARED - NOTIFICATION SENT..."
    for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do
        echo "${CLEARED_ALERTS_ARRAY[i]} (Downtime: ${CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]})"
    done
    echo
    # Print previous alerts
    echo "PREVIOUSLY ALERTED - CONTAINER STILL NOT RUNNING..."
    for i in "${!CONTINUING_ALERTS_ARRAY[@]}"; do
        echo "${CONTINUING_ALERTS_ARRAY[i]} (Downtime: ${CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]})"
    done
    echo

    echo "=================================="
    printf "%-29s ${blue}%3s${reset}\n" "No. containers checked:" "$CONTAINERS_CHECKED"
    printf "%-29s ${blue}%3s${reset}\n" "No. containers running:" "$CONTAINERS_RUNNING"
    printf "%-29s ${blue}%3s${reset}\n" "No. containers NOT running:" "$CONTAINERS_NOT_RUNNING"
    echo "----------------------------------"
    printf "%-29s ${yellow}%3s${reset}\n" "No. existing warnings:" "${#FIRST_WARN_FILE_ARRAY[@]}"
    printf "%-29s ${yellow}%3s${reset}\n" "No. new warnings:" "${#NEW_WARNINGS_ARRAY[@]}"
    printf "%-29s ${yellow}%3s${reset}\n" "No. prev warnings cleared:" "${#CLEARED_WARNINGS_ARRAY[@]}"
    echo "----------------------------------"
    printf "%-29s ${magenta}%3s${reset}\n" "No. existing alerts:" "${#EXISTING_ALERT_FILE_ARRAY[@]}"
    printf "%-29s ${magenta}%3s${reset}\n" "No. new alerts:" "${#NEW_ALERTS_ARRAY[@]}"
    printf "%-29s ${magenta}%3s${reset}\n" "No. prev alerts cleared:" "${#CLEARED_ALERTS_ARRAY[@]}"
    printf "%-29s ${magenta}%3s${reset}\n" "No. continuing alerts:" "${#CONTINUING_ALERTS_ARRAY[@]}"
    echo "=================================="
    echo

fi



# ======================================================================================================================================
# NEW ALERT NOTIFICATIONS
# ======================================================================================================================================

# Send individual error notifications (if flag set)
if [[ ! $NEW_ALERTS_STRING == "" ]]; then

    # loop through errors
    echo "-----------------------------------------------------"
    for i in "${!NEW_ALERTS_ARRAY[@]}"; do
        
        echo "Individual service failure notifications ON, processing notifications for: ${NEW_ALERTS_ARRAY[i]} ..."

        SUBJECT="DOCKER CRONTAB MONITOR - ${NEW_ALERTS_ARRAY[i]} CONTAINER DOWN!!!"
        MSG="${NEW_ALERTS_ARRAY[i]} down @ $(date)"

        if [[ $NOTIFY_EVERY_INSTANCE == 1 ]]; then
            # PushBullet
            if [[ $NOTIFY_PB == 1 ]]; then pushbullet "$SUBJECT" "$MSG"; echo -e "\tPushBullet Sent"; fi
            # PushOver
            if [[ $NOTIFY_PO == 1 ]]; then pushover -c "$NOTIFY_PO_CHANNEL" -T "$SUBJECT" -m "$MSG"; echo -e "\tPushOver Sent"; fi
            # Slack
            if [[ $NOTIFY_SLACK == 1 ]]; then slack -u "$NOTIFY_SLACK_USER" -c "$NOTIFY_SLACK_CHANNEL" -T "$SUBJECT" -t "$MSG" -e "$NOTIFY_SLACK_ICON" -C "red"; echo -e "\tSlack Sent"; fi
        fi

        if [[ $NOTIFY_EMAIL_INSTANCES == 1 ]]; then echo "$MSG" | $MAIL_BIN -s "$SUBJECT" "$EMAIL_ADDRESS"; echo -e "\tEmail Sent"; fi
        
    done
    echo "-----------------------------------------------------"; echo
fi




# Send summary error notifications if NEW_ALERTS_STRING string not empty (if flag set)
if [[ ! $NEW_ALERTS_STRING == "" ]]; then

    echo "-----------------------------------------------------"
    echo "Summary service failure notifications ON, processing notifications ..."

    SUBJECT="DOCKER CRONTAB MONITOR - ${#NEW_ALERTS_ARRAY[@]} CONTAINERS DOWN!!!"
    MSG="$NEW_ALERTS_STRING down @ $(date)"

    if [[ $NOTIFY_SUMMARY == 1 ]]; then
        # PushBullet
        if [[ $NOTIFY_PB == 1 ]]; then pushbullet "$SUBJECT" "$MSG"; echo -e "\tPushBullet Sent"; fi
        # PushOver
        if [[ $NOTIFY_PO == 1 ]]; then pushover -c "$NOTIFY_PO_CHANNEL" -T "$SUBJECT" -m "$MSG"; echo -e "\tPushOver Sent"; fi
        # Slack
        if [[ $NOTIFY_SLACK == 1 ]]; then slack -u "$NOTIFY_SLACK_USER" -c "$NOTIFY_SLACK_CHANNEL" -T "$SUBJECT" -t "$MSG" -e "$NOTIFY_SLACK_ICON" -C "red"; echo -e "\tSlack Sent"; fi
    fi

    if [[ $NOTIFY_EMAIL_SUMMARY == 1 ]]; then echo "$MSG" | $MAIL_BIN -s "$SUBJECT" "$EMAIL_ADDRESS"; echo -e "\tEmail Sent"; fi

    echo "-----------------------------------------------------"; echo
fi


# ======================================================================================================================================
# CLEARED ALERT NOTIFICATIONS
# ======================================================================================================================================

# Send individual cleared notifications (if flag set)
if [[ ! $CLEARED_ALERTS_STRING == "" ]] && [[ $NOTIFY_ON_RESTORE == 1 ]]; then

    echo "-----------------------------------------------------"
    
    # loop through errors
    for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do

        echo "Individual service restore notifications ON, processing notifications for: ${CLEARED_ALERTS_ARRAY[i]} ..."

        SUBJECT="DOCKER CRONTAB MONITOR - ${CLEARED_ALERTS_ARRAY[i]} CONTAINER UP!!!"
        MSG="${CLEARED_ALERTS_ARRAY[i]} up @ $(date). Container downtime: ${CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]}"

        if [[ $NOTIFY_EVERY_INSTANCE == 1 ]]; then
            # PushBullet
            if [[ $NOTIFY_PB == 1 ]]; then pushbullet "$SUBJECT" "$MSG"; echo -e "\tPushBullet Sent"; fi
            # PushOver
            if [[ $NOTIFY_PO == 1 ]]; then pushover -c "$NOTIFY_PO_CHANNEL" -T "$SUBJECT" -m "$MSG"; echo -e "\tPushOver Sent"; fi
            # Slack
            if [[ $NOTIFY_SLACK == 1 ]]; then slack -u "$NOTIFY_SLACK_USER" -c "$NOTIFY_SLACK_CHANNEL" -T "$SUBJECT" -t "$MSG" -e "$NOTIFY_SLACK_ICON" -C "green"; echo -e "\tSlack Sent"; fi
        fi
    
        if [[ $NOTIFY_EMAIL_INSTANCES == 1 ]]; then echo "$MSG" | $MAIL_BIN -s "$SUBJECT" "$EMAIL_ADDRESS"; echo -e "\tEmail Sent"; fi

    done
    
    echo "-----------------------------------------------------"; echo
fi



# Send summary cleared notifications if CLEARED_ALERTS_STRING string not empty (if flag set)
if [[ ! $CLEARED_ALERTS_STRING == "" ]] && [[ $NOTIFY_ON_RESTORE == 1 ]]; then
  
    echo "-----------------------------------------------------"
    echo "Summary service restore notifications ON, processing notifications..."

    SUBJECT="DOCKER CRONTAB MONITOR - ${#CLEARED_ALERTS_ARRAY[@]} CONTAINERS UP!!!"
    MSG="$CLEARED_ALERTS_STRING up @ `date`"

    if [[ $NOTIFY_SUMMARY == 1 ]]; then
        # PushBullet
        if [[ $NOTIFY_PB == 1 ]]; then pushbullet "$SUBJECT" "$MSG"; echo -e "\tPushBullet Sent"; fi
        # PushOver
        if [[ $NOTIFY_PO == 1 ]]; then pushover -c "$NOTIFY_PO_CHANNEL" -T "$SUBJECT" -m "$MSG"; echo -e "\tPushOver Sent"; fi
        # Slack
        if [[ $NOTIFY_SLACK == 1 ]]; then slack -u "$NOTIFY_SLACK_USER" -c "$NOTIFY_SLACK_CHANNEL" -T "$SUBJECT" -t "$MSG" -e "$NOTIFY_SLACK_ICON" -C "red"; echo -e "\tSlack Sent"; fi
    fi

    if [[ $NOTIFY_EMAIL_SUMMARY == 1 ]]; then echo "$MSG" | $MAIL_BIN -s "$SUBJECT" "$EMAIL_ADDRESS"; echo -e "\tEmail Sent"; fi

    echo "-----------------------------------------------------"; echo

fi


# ======================================================================================================================================
# NODEEXPORTER
# ======================================================================================================================================


# Send nodeexporter alerts - both new alerts and cleared alerts can be logged in same file.
# Need to have a solution which can write multiple lines to the NodeExporter metrics file
# since multiple container updates will overwrite the target file immediately so NodeExporter
# will not have a chance to read it. So can't use our customised logging script.

if [[ $NOTIFY_NODEEXPORTER == 1 ]]; then
  if [[ ! $NEW_ALERTS_STRING == "" ]] || [[ ! $CLEARED_ALERTS_STRING == "" ]] || [[ ! $NEW_WARNINGS_STRING == "" ]]; then
    
    echo "-----------------------------------------------------"   
    echo "NodeExporter logging"
    
    # Clear existing file content
    echo "" | tee $NODEEXPORTER_PATH
    
    if [[ ! $NEW_ALERTS_STRING == "" ]]; then
        echo -e "\tCreating nodeexporter output for containers down..."
        # Loop through new errors
        for i in "${!NEW_ALERTS_ARRAY[@]}"; do
            echo "node_docker_container_down{name=\"${NEW_ALERTS_ARRAY[i]}\"} 1" | tee -a $NODEEXPORTER_PATH
        done
    fi

    if [[ ! $CLEARED_ALERTS_STRING == "" ]]; then
        echo -e "\tCreating nodeexporter output for containers up..."
        # Loop through cleared errors
        for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do
            echo "node_docker_container_down{name=\"${CLEARED_ALERTS_ARRAY[i]}\"} 0" | tee -a $NODEEXPORTER_PATH
        done
    fi
    
    # Create metrics to record container stop time in unix epoch format
    # Using this script's run time as proxy for stop time.
    # Can be used to display metrics/annotations in Grafana.
    if [[ ! $NEW_WARNINGS_STRING == "" ]]; then
        echo -e "\tCreating nodeexporter output for new warnings (record failure time)..."
        EPOCH_TIME=$(date +%s)
        EPOCH_TIME=$(expr $EPOCH_TIME - 300)    # Subtract 5m for middle of 10min periodic crontab timing. Already approximate so not critical.
        # Loop through new warnings
        for i in "${!NEW_WARNINGS_ARRAY[@]}"; do
            EPOCH_TIME=$(expr $EPOCH_TIME + 15)    # Stop time already approximate, adding gap in case multiple containers for better visability in Grafana annotations
            echo "node_docker_container_stop_time_seconds{name=\"${NEW_WARNINGS_ARRAY[i]}\"} $EPOCH_TIME" | tee -a $NODEEXPORTER_PATH
        done
    fi

    echo "-----------------------------------------------------"; echo
    
    # Previous solution using a custom 'logger' script to parse NodeExporter updates.
    #NodeExporter -> Prometheus (Arguments: $1 = action, $2 = storage, $3=1(start)/0(stop))
    #for i in "${!NEW_ALERTS_ARRAY[@]}"; do
    #    echo "Sending nodeexporter notification for containers down: "${NEW_ALERTS_ARRAY[i]}
    #    #$NODEEXPORTER_SCRIPT_PATH docker_container_down ${NEW_ALERTS_ARRAY[i]} 1
    #done
    #for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do
    #    echo "Sending nodeexporter notification for container back up: "${CLEARED_ALERTS_ARRAY[i]}
    #    $NODEEXPORTER_SCRIPT_PATH docker_container_down $STORAGE ${CLEARED_ALERTS_ARRAY[i]} 0
    #done

  fi
fi


# ======================================================================================================================================
# VICTORIAMETRICS
# ======================================================================================================================================

# Not using custom helper script since easier to push individual metrics as/when needed instead of
# managing text file contents.

if [[ $NOTIFY_VICTORIAMETRICS == 1 ]]; then
  if [[ ! $NEW_ALERTS_STRING == "" ]] || [[ ! $CLEARED_ALERTS_STRING == "" ]] || [[ ! $NEW_WARNINGS_STRING == "" ]]; then
    
    echo "-----------------------------------------------------"   
    echo "VictoriaMetrics logging"
    
    if [[ ! $NEW_ALERTS_STRING == "" ]]; then
        echo -e "\tPushing metrics to VictoriaMetrics for containers down..."
        # Loop through new errors
        for i in "${!NEW_ALERTS_ARRAY[@]}"; do
            curl -X POST "${NOTIFY_VICTORIAMETRICS_HOST}/api/v1/import/prometheus?extra_label=host_system=$HOSTNAME" \
                -d "docker_crontab_monitor_docker_container_down{name=\"${NEW_ALERTS_ARRAY[i]}\"} 1"
        done
    fi

    if [[ ! $CLEARED_ALERTS_STRING == "" ]]; then
        echo -e "\tPushing metrics to VictoriaMetrics for containers up..."
        # Loop through cleared errors
        for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do
            curl -X POST "${NOTIFY_VICTORIAMETRICS_HOST}/api/v1/import/prometheus?extra_label=host_system=$HOSTNAME" \
                -d "docker_crontab_monitor_docker_container_down{name=\"${CLEARED_ALERTS_ARRAY[i]}\"} 0"
        done
    fi
    
    
    # Create metrics to log container stop time in unix epoch format
    # Using this script's run time as proxy for stop time.
    # Can be used to display annotations in Grafana.
    if [[ ! $NEW_WARNINGS_STRING == "" ]]; then
        echo -e "\tCreating VictoriaMetrics metrics to track container stop time. output for new warnings (record failure time)..."
        EPOCH_TIME=$(date +%s)
        EPOCH_TIME=$(expr $EPOCH_TIME - 300)    # Subtract 5m for middle of 10min periodic crontab timing. Already approximate so not critical.
        # Loop through new warnings
        for i in "${!NEW_WARNINGS_ARRAY[@]}"; do
            EPOCH_TIME=$(expr $EPOCH_TIME + 15)    # Stop time already approximate, adding gap in case multiple containers for better visability in Grafana annotations
            curl -X POST "${NOTIFY_VICTORIAMETRICS_HOST}/api/v1/import/prometheus?extra_label=host_system=$HOSTNAME" \
                -d "docker_crontab_monitor_docker_container_stop_time_seconds{name=\"${NEW_WARNINGS_ARRAY[i]}\"} $EPOCH_TIME"
        done
    fi

    echo "-----------------------------------------------------"; echo

  fi
fi


# ======================================================================================================================================
# UPDATE LOGS
# ======================================================================================================================================

# Update current alert list
printf "%-17s %-50s %-21s\n" "DateTime" "Container" "Downtime" > $LOG_EXISTING_ALERTS
printf "%-17s %-50s %-21s\n" "---------------" "--------------------------------------------------" "---------------------" >> $LOG_EXISTING_ALERTS
for i in "${!CONTINUING_ALERTS_ARRAY[@]}"; do
    printf "%-17s %-50s %-21s\n" "${CONTINUING_ALERTS_START_ARRAY[i]}" "${CONTINUING_ALERTS_ARRAY[i]}" "${CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]}" >> $LOG_EXISTING_ALERTS
done
for i in "${!NEW_ALERTS_ARRAY[@]}"; do
    printf "%-17s %-50s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${NEW_ALERTS_ARRAY[i]}" >> $LOG_EXISTING_ALERTS
done

# Update warnings list
printf "%-17s %-50s\n" "DateTime" "Container" > $LOG_FIRST_WARN
printf "%-17s %-50s\n" "---------------" "----------------------" >> $LOG_FIRST_WARN
for i in "${!NEW_WARNINGS_ARRAY[@]}"; do
    printf "%-17s %-50s\n" "$(date +%Y%m%d-%H%M%S)" "${NEW_WARNINGS_ARRAY[i]}" >> $LOG_FIRST_WARN
done

# LOG_ALERT_HISTORY header - only uncomment if starting log from scratch
#printf "%-17s %-40s %-35s %-21\n" "DATE-TIME" "CONTAINER NAME" "STATUS" "DOWNTIME" > $LOG_ALERT_HISTORY
#printf "%-17s %-40s %-35s %-21\n" "-----------------" "----------------------------------------" "----------------" "---------------------" >> $LOG_ALERT_HISTORY
# Add entry to alerts log for new and cleared alerts
# Loop through new alerts
for i in "${!NEW_ALERTS_ARRAY[@]}"; do
    printf "%-17s %-40s %-35s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${NEW_ALERTS_ARRAY[i]}" "Container Down - Alert Sent" "" >> $LOG_ALERT_HISTORY
done
# loop through cleared alerts
for i in "${!CLEARED_ALERTS_ARRAY[@]}"; do
    printf "%-17s %-40s %-35s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${CLEARED_ALERTS_ARRAY[i]}" "Container Back Up" "${CLEARED_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]}" >> $LOG_ALERT_HISTORY
done
# Loop through continuing alerts (could cause LARGE log file if not commented out)
#for i in "${!CONTINUING_ALERTS_ARRAY[@]}"; do
#    printf "%-17s %-40s %-35s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${CONTINUING_ALERTS_ARRAY[i]}" "Container Still Down" "${CONTINUING_ALERTS_DURATION_SECS_PRETTY_ARRAY[i]}" >> $LOG_ALERT_HISTORY
#done
# Loop through new warnings
for i in "${!NEW_WARNINGS_ARRAY[@]}"; do
    printf "%-17s %-40s %-35s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${NEW_WARNINGS_ARRAY[i]}" "Warning - Container Down - No Alert" "" >> $LOG_ALERT_HISTORY
done
# Loop through cleared warnings
for i in "${!CLEARED_WARNINGS_ARRAY[@]}"; do
    printf "%-17s %-40s %-35s %-21s\n" "$(date +%Y%m%d-%H%M%S)" "${CLEARED_WARNINGS_ARRAY[i]}" "Warning Cleared - Container Back Up" "" >> $LOG_ALERT_HISTORY
done

# Output full alert history
#if [[ $DEBUG == 1 ]]; then cat $LOG_ALERT_HISTORY; fi


echo; echo




