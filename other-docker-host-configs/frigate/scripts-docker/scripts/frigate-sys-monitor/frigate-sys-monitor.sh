#!/bin/bash

# Run in crontab
# Monitors disk space and restarts frigate if disk space exceeds DISK_THRESHOLD.

# Created March 25 when Frigate was regularly causing /var/lib/docker/overlay2/* to fill up and use 
# all available disk space. Which caused LXC to become unresponsive.

# Search log for breaches with keywords: !!! Threshold Breach
# Log at (LKOGFILE variable): /var/log/docker/frigate-sys-monitor/frigate-sys-monitor.log

# Check running as root - attempt to restart with sudo if not already running with root
if [ "$(id -u)" -ne 0 ]; then echo "$(tput setaf 1)Not running as root, attempting to automatically restart script with root access...$(tput sgr0)"; echo; sudo "$0" "$@"; exit 1; fi

# CHECK DISK USAGE?
DISK_USE_CHECK=1
DISK_THRESHOLD=85  # Disk usage percentage threshold
DISK_MONITOR_PATH="/var/lib/docker/overlay2"  # Path to your Frigate container

# CHECK MEMORY?
MEM_CHECK=1
MEM_THRESHOLD=85  

# DOCKER
DOCKER_RESTART=1   # Can also be set to 0, to only notify on breaches
COMPOSE_FILE="/root/scripts/docker/frigate.yml"  # Path to docker compose file
CONTAINERS="frigate"  # Comma separated list of CONTAINERS (from compose file) to restart. Use 'all' to restart full compose file stack.

# SEND NOTIFICATIONS IF THRESHOLDS BREACHED
NOTIFICATIONS=0  # Set to 1 to send notifications when services restarted.
NOTIFY_HELPER="/root/scripts/notification-helper/notify.sh"  # Notification helper script path
# TITLE AND MESSAGE UPDATED BELOW TO ALLOW US TO INCLUDE CALC'D METRICS
#NOTIFY_TITLE="Frigate System Check"
#NOTIFY_MSG="Disk usage ${DISK_USAGE}% exceeds threshold (${DISK_THRESHOLD}%), Frigate restarted"  # Defined below so that we can include disk usage metric
NOTIFY_CHANNEL="alert" # Choose from: alert backup docker media_stack monitor notifications
NOTIFY_SERVICES="all"  # Comma separated list: all,email,po|pushover,pb|pusbullet,slack,discord,telegram

# MISC
LOGFILE="/var/log/docker/frigate-sys-monitor/frigate-sys-monitor.log"
RESTART_RECORD="/var/log/docker/frigate-sys-monitor/frigate-restarts.log"
LOGLENGTH=216000   # Note, each execution takes writes. 15 lines in the log. Executing each minutegive c. 24hrs = 21600 lines
THRESHOLD_BREACHED=0   # Placeholder to update if/when issues found. To trigger docker restart after checks.
DISK_THRESHOLD_BREACH=0   # Placeholder to track if/when breeach detected. Do not change here
MEM_THRESHOLD_BREACH=0   # Placeholder to track if/when breeach detected. Do not change here

### ============================================================================
### SET UP LOGGING
### ============================================================================
# Create log directory if it doesn't exist
mkdir -p "$(dirname ${LOGFILE})"
# Trim log to latest LOGLENGTH lines
tail -n ${LOGLENGTH} "${LOGFILE}" > "/tmp/$(basename "${LOGFILE%.*}").tmp" && mv "/tmp/$(basename "${LOGFILE%.*}").tmp" "${LOGFILE}"
echo "====================================================================================================" | tee -a "${LOGFILE}"
echo "Find breaches in log file by searching for: !!!_Threshold_Breach (replace _ with space)" | tee -a "${LOGFILE}"
echo "$(date +%Y%m%d-%H%M%S): CHECKING FOR THRESHOLD BREACHES ..." | tee -a "${LOGFILE}"

### ============================================================================
### DEPENDANCIES
### ============================================================================

# CHeck 'bc' is installed - required for memory check
if ! command -v bc &> /dev/null; then
    echo "$(date +%Y%m%d-%H%M%S): 'bc' not found, required for memory threshold checking. Installing now ..." | tee -a "${LOGFILE}"
    sudo apt-get update
    sudo apt-get install -y bc
fi

### ============================================================================
### DISK USAGE
### ============================================================================
if [[ ${DISK_USE_CHECK} -eq 1 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): DISK USE - CHECKING THRESHOLD STATUS ..." | tee -a "${LOGFILE}"

    # Get current disk usage percentage
    DISK_USAGE=$(df -h ${DISK_MONITOR_PATH} | grep -v Filesystem | awk '{print $5}' | tr -d '%')

    # Log the current status
    echo "$(date +%Y%m%d-%H%M%S): Current disk usage: ${DISK_USAGE}%" | tee -a "${LOGFILE}"

    # Check if disk usage exceeds threshold
    if [ ${DISK_USAGE} -gt ${DISK_THRESHOLD} ]; then
        echo "$(date +%Y%m%d-%H%M%S): !!! Threshold Breach: Disk usage (${DISK_USAGE}%) exceeds threshold (${DISK_THRESHOLD}%)!" | tee -a "${LOGFILE}"
        DISK_THRESHOLD_BREACH=1
        THRESHOLD_BREACHED=1
    else
        echo "$(date +%Y%m%d-%H%M%S): Disk usage does not exceed threshold (${DISK_THRESHOLD}%)" | tee -a "${LOGFILE}"
    fi
else
    echo "$(date +%Y%m%d-%H%M%S): DISK USE - SKIPPING (disk threshold check not enabled)" | tee -a "${LOGFILE}"
fi

### ============================================================================
### MEMORY USAGE
### ============================================================================
if [[ ${MEM_CHECK} -eq 1 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): MEMORY USE - CHECKING THRESHOLD STATUS ..." | tee -a "${LOGFILE}"

    # Get memory information from /proc/meminfo
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
    MEM_BUFFERS=$(grep Buffers /proc/meminfo | awk '{print $2}')
    MEM_CACHED=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')

    # Calculate used memory (excluding buffers and cache)
    MEM_USED=$((MEM_TOTAL - MEM_FREE - MEM_BUFFERS - MEM_CACHED))
    MEM_AVAIL=$((MEM_FREE + MEM_BUFFERS + MEM_CACHED))

    # Calculate percentage
    MEM_USED_PERC=$((MEM_USED * 100 / MEM_TOTAL))
    MEM_AVAIL_PERC=$((MEM_AVAIL * 100 / MEM_TOTAL))

    # Convert to human-readable format (MB or GB)
    MEM_TOTAL_HUMAN=$(echo "scale=2; $MEM_TOTAL/1024/1024" | bc)
    MEM_USED_HUMAN=$(echo "scale=2; $MEM_USED/1024/1024" | bc)
    MEM_AVAIL_HUMAN=$(echo "scale=2; $MEM_AVAIL/1024/1024" | bc)

    # Display memory usage
    echo "$(date +%Y%m%d-%H%M%S): Memory usage:" | tee -a "${LOGFILE}"
    echo "$(date +%Y%m%d-%H%M%S):     Total: ${MEM_TOTAL_HUMAN}GB" | tee -a "${LOGFILE}"
    echo "$(date +%Y%m%d-%H%M%S):     Used: ${MEM_USED_HUMAN}GB (${MEM_USED_PERC}%)" | tee -a "${LOGFILE}"
    echo "$(date +%Y%m%d-%H%M%S):     Available: ${MEM_AVAIL_HUMAN}GB (${MEM_AVAIL_PERC}%)" | tee -a "${LOGFILE}"

    # Check if usage exceeds threshold
    if [ $MEM_USED_PERC -ge $MEM_THRESHOLD ]; then
        echo "$(date +%Y%m%d-%H%M%S): !!! Threshold Breach: Memory usage (${MEM_USED_PERC}%) exceeds threshold threshold (${MEM_THRESHOLD}%)!" | tee -a "${LOGFILE}"
        MEM_THRESHOLD_BREACH=1
        THRESHOLD_BREACHED=1
    else
        echo "$(date +%Y%m%d-%H%M%S): Memory usage does not exceed threshold (${MEM_THRESHOLD}%)" | tee -a "${LOGFILE}"
    fi

else
    echo "$(date +%Y%m%d-%H%M%S): MEMORY USE - SKIPPING (memory threshold check not enabled)" | tee -a "${LOGFILE}"
fi


### ============================================================================
### EXIT IF O THRESHOLDS BREACHED
### ============================================================================
if [[ ${THRESHOLD_BREACHED} -eq 0 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): >>> No Threshold breaches detected - exiting script <<<" | tee -a "${LOGFILE}"
    echo; exit 0
fi


### ============================================================================
### RESTART DOCKER SERVICES
### ============================================================================
if [[ ${DOCKER_RESTART} -eq 1 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): DOCKER RESTART ..." | tee -a "${LOGFILE}"

    if [[ ${THRESHOLD_BREACHED} -eq 1 ]]; then
        echo "$(date +%Y%m%d-%H%M%S): Threshold(s) breached - restarting '${CONTAINERS}' services from ${COMPOSE_FILE} ..." | tee -a "${LOGFILE}"
        
        if [[ "${CONTAINERS}" == "all" ]]; then
            docker compose -f "$COMPOSE_FILE" up -d --force-recreate 
        else
            IFS="," read -r -a containers_arr <<< "$CONTAINERS"
            for i in "${containers_arr[@]}"; do
                docker compose -f "$COMPOSE_FILE" up -d --force-recreate "$i"
            done  
        fi
        
        echo "$(date +%Y%m%d-%H%M%S): Containers restarted (${CONTAINERS})" | tee -a "${LOGFILE}"
        echo "$(date +%Y%m%d-%H%M%S): Containers restarted (${CONTAINERS})" | tee -a "${RESTART_RECORD}"
    else
        echo "$(date +%Y%m%d-%H%M%S): Docker restart enabled but not required, thresholds not breached" | tee -a "${LOGFILE}"
    fi
else
    echo "$(date +%Y%m%d-%H%M%S): DOCKER RESTART - SKIPPING (docker restart not enabled)" | tee -a "${LOGFILE}"
fi

### ============================================================================
### NOTIFY ON THRESHOLD BREACHES
### ============================================================================
# Setup notification title & message
if [[ ${THRESHOLD_BREACHED} -eq 1 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): NOTIFICATION PREP ..." | tee -a "${LOGFILE}"
    NOTIFY_TITLE="Frigate Sys Monitor - Thresholds Breached:"
    NOTIFY_MSG="Errors Detected By Monitor"
    if [[ ${DISK_THRESHOLD_BREACH} -eq 1 ]]; then
        NOTIFY_TITLE="${NOTIFY_TITLE} Disk-Space"
        NOTIFY_MSG="${NOTIFY_MSG} | Disk usage ${DISK_USAGE}% exceeds ${DISK_THRESHOLD}% threshold"
    fi
    if [[ ${MEM_THRESHOLD_BREACH} -eq 1 ]]; then
        NOTIFY_TITLE="${NOTIFY_TITLE} Memory"
        NOTIFY_MSG="${NOTIFY_MSG} | Memory usage ${MEM_USED_PERC}% exceeds ${MEM_THRESHOLD}% threshold"
    fi
    if [[ ${DOCKER_RESTART} -eq 1 ]]; then
        NOTIFY_MSG="${NOTIFY_MSG} | Docker Services Restarted"
    else
        NOTIFY_MSG="${NOTIFY_MSG} | Docker Services NOT Restarted"
    fi

    echo "$(date +%Y%m%d-%H%M%S): Notification title: ${NOTIFY_TITLE}" | tee -a "${LOGFILE}"
    echo "$(date +%Y%m%d-%H%M%S): Notification message: ${NOTIFY_MSG}" | tee -a "${LOGFILE}"
fi

if [[ ${NOTIFICATIONS} -eq 1 ]]; then
    echo "$(date +%Y%m%d-%H%M%S): NOTIFICATIONS ..." | tee -a "${LOGFILE}"

    if [[ ${THRESHOLD_BREACHED} -eq 1 ]]; then 

        if [[ ! -x "${NOTIFY_HELPER}" ]]; then
            echo "$(date +%Y%m%d-%H%M%S): ERROR - Notifications enabled but 'notification helper' script not found in specified location (${NOTIFY_HELPER})!" | tee -a "${LOGFILE}"
        else
            echo "$(date +%Y%m%d-%H%M%S): Threshold(s) breached - sending notifications ..." | tee -a "${LOGFILE}"
            NOTIFYCMD=("$NOTIFY_HELPER")
            NOTIFYCMD+=("-e \"set content_type=text/html\"")
            NOTIFYCMD+=(" --title '${NOTIFY_TITLE}' ")
            NOTIFYCMD+=(" --msg '${NOTIFY_MSG}' ")
            NOTIFYCMD+=(" --channel '${NOTIFY_CHANNEL}' ")
            NOTIFYCMD+=(" --services '${NOTIFY_SERVICES}' ")
            eval "${NOTIFYCMD[@]}"
            echo "$(date +%Y%m%d-%H%M%S): Notifications sent!" | tee -a "${LOGFILE}"
        fi

    else
        echo "$(date +%Y%m%d-%H%M%S): Notifications enabled but threshold(s) not breached - not sending notifications" | tee -a "${LOGFILE}"
    fi
else
    echo "$(date +%Y%m%d-%H%M%S): NOTIFICATIONS - SKIPPING (notifications not enabled)" | tee -a "${LOGFILE}"
fi