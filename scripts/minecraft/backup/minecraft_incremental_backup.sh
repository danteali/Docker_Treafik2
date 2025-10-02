#!/bin/bash
# shellcheck disable=SC2027
echo ""
#red=$(tput setaf 1)
#green=$(tput setaf 2)
#yellow=$(tput setaf 3)
#blue=$(tput setaf 4)
#magenta=$(tput setaf 5)
#cyan=$(tput setaf 6)
#under=$(tput sgr 0 1)
#reset=$(tput sgr0)
#isnum='^[0-9]+$'

# RDIFF_BACKUP HELPER SCRIPT FOR MINECRAFT BACKUPS
# Variables to pass on command line:
#   - container name
#   - data / source dir
#   - backup / destination dir
#   - retention period for old backup increments
#
# Data dir contents will be backed up based on content of the rdiff file list file
# which is in the same directory as this script.

# rdiff-backup notes on using include/exclude files to list files:
# http://rdiff-backup.nongnu.org/examples.html
#
# Note that the --include-globbing-filelist instead of
# --include-filelist so that the lines would be interpreted as if they
# were specified on the command line.
#
# Note that multiple include and exclude options take precedence in
# the order they are given.
# e.g. rdiff-backup --include '**txt' \
#                   --exclude /usr/local/games \
#                   --include /usr/local \
#                   --exclude /usr \
#                   --exclude /backup \
#                   --exclude /proc 
#                   / /backup
# The above command will back up any file ending in txt, even
# /usr/local/games/pong/scores.txt because that include has highest
# precedence. The contents of the directory /usr/local/bin will get
# backed up, but not /usr/share or /usr/local/games/pong.
#
# rdiff-backup can also accept a list of files to be backed up. If the
# file include-list contains these two lines:
#     /var
#     /usr/bin/gzip
# Then this command:
#     rdiff-backup --include-filelist include-list \
#                  --exclude '**' \
#                  / /backup
# would only back up the files /var, /usr, /usr/bin, and 
# /usr/bin/gzip, but not /var/log or /usr/bin/gunzip. Note that this
# differs from the --include option, since --include /var would also
# match /var/log.
#
# The same file list can both include and exclude files. If we create
# a file called include-list that contains these lines:
#     **txt
#     - /usr/local/games
#     /usr/local
#     - /usr
#     - /backup
#     - /proc
# Then the following command will do exactly the same thing as the
# complicated example two above.
#     rdiff-backup --include-globbing-filelist include-list \
#                  / /backup
# Above we have used --include-globbing-filelist instead of
# --include-filelist so that the lines would be interpreted as if they
# were specified on the command line. Otherwise, for instance, **txt
# would be considered the name of a file, not a globbing string.

# More detailed rdiff-backup notes are in OneNote but some useful commands are...
# To list backup revisions:
#    rdiff-backup --list-increments backup/
# To restore files (using the time format in the above list output): 
#    rdiff-backup --restore-as-of 2019-08-03T23:08:34 backup/ data/
#    rdiff-backup --restore-as-of 2019-08-03T23:08:34 backup/server.properties data/server.properties
# To list changed files between dest and source dir (using the time format in the above list output):
#    rdiff-backup --compare data/ backup/
#    rdiff-backup --compare-at-time 2019-08-03T23:08:34 data/ backup/
# To list backup files changed since particular time (using the time format in the above list output):
#    rdiff-backup --list-changed-since 2019-08-03T23:08:34 backup/
# To delete old files (an existing file which hasn't changed for a year will still be preserved. But
# a file which was deleted 15 days ago cannot be restored after this command is run):
#    rdiff-backup --remove-older-than 2W host.net::/remote-dir
#
# When restoring the default behaviour is to restore the destination to exactly how it looked at 
# the defined date so it will delete existing files if they were not there at that date. It also 
# deletes excluded files.
# So if restoring we may need to restore to a different dirctory (e.g. restored/) then move/copy the
# restored files to the data/ dir. Otherwise we lose all the plugin .jars etc


# ====================================================================
# INITIAL VARIABLES
# ====================================================================
DEBUG=0 # Use during dev to pause throughout script
# Set above to 1 and use below code to pause during development if needed.
if [[ $DEBUG == 1 ]]; then read -r -p "Press key to continue..."; fi

WHOAMI=$(basename "$0")
DIRSCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"  # if using symlink, gives symlink location
DIRSCRIPTREAL="$(echo $(readlink -f "$0") | sed 's:[^/]*$::')"                  # give script path even if using symllink
DIRSCRIPTREAL=${DIRSCRIPTREAL::-1}
INCLUDEFILELIST="$DIRSCRIPTREAL/minecraft_incremental_backup_include.txt"
LOGFILE="$DIRSCRIPT/${WHOAMI%%.*}.log"
LOGFILEMAXSIZE=2000000 # Trim the log in half when it gets to this size (bytes)
BACKUPSKEEPDEFAULT="2W"

# ====================================================================
# LOG MANAGEMENT
# ====================================================================
# LOG SIZE
LOGFILESIZE=$(stat -c%s "$LOGFILE")

# CHECK IF LOG FILE IS TOO BIG - CUT IN HALF IF IT IS
if [[ $LOGFILESIZE -gt $LOGFILEMAXSIZE ]]; then
    # Count log lines and split in half
    LOGLINECOUNT=$(cat $LOGFILE | wc -l)
    LOGLINECOUNTHALF=$(( $LOGLINECOUNT / 2 ))
    # Remove lines 1 to LOGLINECOUNTHALF
    sed -i -e "1,"$LOGLINECOUNTHALF"d" "$LOGFILE"
    # Add note to top of log to confirm trimming
    sed -i "1s/^/<<<<< file trimmed $(date +%Y%m%d-%H%M%S) >>>>> \n/" "$LOGFILE"
    # Append message to end of log to confirm trim happened (use human readable) format for quoting size
    LOGFILEMAXSIZE_H=$(numfmt $LOGFILEMAXSIZE --to=si)
    echo "" | tee -a "$LOGFILE"
    echo "================================================================================================" | tee -a "$LOGFILE"
    echo "" | tee -a "$LOGFILE"
    echo "[$(date +%Y%m%d-%H%M%S)] LOG FILE SIZE GREATER THAN LIMIT ($LOGFILEMAXSIZE_H) - TRIMMED START OF LOG FILE " | tee -a "$LOGFILE"
fi

# INITIALISE LOG FOR THIS JOB
echo "" | tee -a "$LOGFILE"
echo "================================================================================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "[$(date +%Y%m%d-%H%M%S)] Starting backup script..." | tee -a "$LOGFILE"


# ====================================================================
# PARSE ARGUMENTS - ARGS CAN BE PASSED IN ANY ORDER
# ====================================================================
        while test $# -gt 0; do
          case "$1" in
            -h|--help)
              echo                                                                                                                                                #|
              echo "RDIFF-BACKUP HELPER FOR DOCKER MINECRAFT"
              echo 
              echo "Usage:"
              echo "./$WHOAMI [tbc]" 
              echo 
              echo "NOTHING WILL BE BACKED UP UNLESS SPECIFIED IN THE RDIFF FILE LIST"
              echo ""
              echo "Note that a log of the backup jobs is saved in the same directory as the script file (or the directory that a symlink is located). rdiff-backup"
              echo "also creates a detailed log of the backups inside the backup's 'rdiff-backup-data/backup.log' file."
              echo
              echo "See 'archive' folder for paper server backup script"
              echo
              echo "OPTIONS                      DETAILS"
              echo "-h --help                    Show help"
              echo "-c --container               Specifiy name of minecraft container."
              echo "                             Autosaving will be paused if container is running during backup."
              echo "-d --data-dir                Specifiy location of files to be backed up."
              echo "                             Can be a full path, or can be a subfolder of this script's path (or a symlink to this script)."
              echo "-b --backup-dir              Specifiy location of files to be backed up."
              echo "                             Can be a full path, or can be a subfolder of this script's path (or a symlink to this script)."
              echo "-s --skip-existing-check     By default script will heck for existing minecraft rdiff-backup jobs running and will not run"
              echo "                             if any are found."
              echo
              echo "EXAMPLES"
              echo
              exit 0
              ;;

            # SKIP CHECK FOR ALREADY RUNNING JOBS?
            -s|--skip-existing-check)
                SKIP_EXISTING_CHECK=1
              shift
              ;;

            # DEFINE CONTAINER NAME
            -c=*|--container=*)
              MINECRAFTCONTAINER=$(echo $1 | sed -e 's/^[^=]*=//g')    
              shift
              ;;
            -c|--container)
              shift
              if test $# -gt 0; then
                MINECRAFTCONTAINER=$1
              else
                echo "**ERROR: Container - not specified**" | tee -a "$LOGFILE"
                exit 1
              fi
              shift
              ;;

            # DEFINE DATA (SOURCE) DIR
            -d=*|--data-dir=*)
              DIRDATA=$(echo $1 | sed -e 's/^[^=]*=//g')
              shift
              ;;
            -d|--data-dir)
              shift
              if test $# -gt 0; then
                DIRDATA=$1
              else
                echo "**ERROR: Data Dir - not specified**" | tee -a "$LOGFILE"
                exit 1
              fi
              shift
              ;;

            # DEFINE BACKUP (DESTINATION) DIR
            -b=*|--backup-dir=*)
              DIRBACKUP=$(echo $1 | sed -e 's/^[^=]*=//g')
              shift
              ;;
            -b|--backup-dir)
              shift
              if test $# -gt 0; then
                DIRBACKUP=$1
              else
                echo "**ERROR: Backup Dir - not specified**" | tee -a "$LOGFILE"
                exit 1
              fi
              shift
              ;;

            # DEFINE RETENTION PERIOD
            -r=*|--retention=*)
              BACKUPSKEEP=$(echo $1 | sed -e 's/^[^=]*=//g')
              shift
              ;;
            -r|--retention)
              shift
              if test $# -gt 0; then
                BACKUPSKEEP=$1
              else
                echo "**ERROR: Retention Period - not specified**" | tee -a "$LOGFILE"
                exit 1
              fi
              shift
              ;;

            *)
              break
              ;;
          esac
        done




# ====================================================================
# PARSE USER-SUPPLIED VARIABLES
# ====================================================================

# CONTAINER NAME
if [[ -z $MINECRAFTCONTAINER ]]; then
    echo "**ERROR: Container - No Minecraft container specified**" | tee -a "$LOGFILE"
    exit 1
else
    if docker ps | grep -qs "$MINECRAFTCONTAINER"; then
        echo "Container - $MINECRAFTCONTAINER - Running: Yes" | tee -a "$LOGFILE"
        CONTAINERRUNNING=1
    else
        echo "Container - $MINECRAFTCONTAINER - Running: No" | tee -a "$LOGFILE"
        CONTAINERRUNNING=0
    fi
fi

# DATA (SOURCE) DIR
if [[ -z $DIRDATA ]]; then
    echo "**ERROR: Data Dir - not specified**" | tee -a "$LOGFILE"
    exit 1
else
    # Check data dir exists (add leading '/' to check if we have a full path - no impact if already got leading '/')
    if [[ ! -d "/$DIRDATA" ]]; then
        # Check it's not a reference to a subdir of the directory containing script
        if [[ ! -d "$DIRSCRIPT/$DIRDATA" ]]; then
            echo "**ERROR: Data Dir - not found at:" | tee -a "$LOGFILE"
            echo "    $DIRDATA" | tee -a "$LOGFILE"
            echo "    $DIRSCRIPT/$DIRDATA **" | tee -a "$LOGFILE"
            exit 1
        else
            echo "Data Dir - found at: $DIRSCRIPT/$DIRDATA" | tee -a "$LOGFILE"
            DIRDATA="$DIRSCRIPT/$DIRDATA"
        fi
    else
        echo "Data Dir: found at: $DIRDATA" | tee -a "$LOGFILE"
    fi
fi


# BACKUP DIR
if [[ -z $DIRBACKUP ]]; then
    echo "**ERROR: Backup Dir - not specified**" | tee -a "$LOGFILE"
    exit 1
else
    # Check data dir exists (add leading '/' to check if we have a full path - no impact if already got leading '/')
    if [[ ! -d "/$DIRBACKUP" ]]; then
        # Check it's not a reference to a subdir of the directory containing script
        if [[ ! -d "$DIRSCRIPT/$DIRBACKUP" ]]; then
            echo "**ERROR: Backup Dir - not found at:" | tee -a "$LOGFILE"
            echo "    $DIRBACKUP" | tee -a "$LOGFILE"
            echo "    $DIRSCRIPT/$DIRBACKUP **" | tee -a "$LOGFILE"
            exit 1
        else
            echo "Backup Dir - found at: $DIRSCRIPT/$DIRBACKUP" | tee -a "$LOGFILE"
            DIRBACKUP="$DIRSCRIPT/$DIRBACKUP"
        fi
    else
        echo "Backup Dir - found at: $DIRBACKUP" | tee -a "$LOGFILE"
    fi
fi

if [[ -z $BACKUPSKEEP ]]; then
    echo -e "Retention Period - defined in command args, using default: $BACKUPSKEEPDEFAULT"; echo
    BACKUPSKEEP=$BACKUPSKEEPDEFAULT
fi

# RETENTION PERIOD
if [[ -z $BACKUPSKEEP ]]; then
    BACKUPSKEEP=$BACKUPSKEEPDEFAULT
    echo "Retention Period - Using user supplied value: $BACKUPSKEEP"
else
    echo "Retention Period - Using default value: $BACKUPSKEEP"
fi

# DOUBLE CHECK HARD CODED INCLUDE FILE EXISTS
if [[ ! -f $INCLUDEFILELIST ]]; then
    echo "**ERROR: Include List File - doesn't exist ... check script!**"
    exit 1
fi

# ====================================================================
# LOG VARIABLES
# ====================================================================
echo "" | tee -a "$LOGFILE"
echo "[$(date +%Y%m%d-%H%M%S)] Defined variables:" | tee -a "$LOGFILE"
    echo -e "    DEBUG\t\t = $DEBUG" | tee -a "$LOGFILE"
    echo -e "    DIRSCRIPT\t\t = $DIRSCRIPT" | tee -a "$LOGFILE"
    echo -e "    DIRSCRIPTREAL\t = $DIRSCRIPTREAL" | tee -a "$LOGFILE"
    echo -e "    DIRDATA\t\t = $DIRDATA" | tee -a "$LOGFILE"
    echo -e "    DIRBACKUP\t\t = $DIRBACKUP" | tee -a "$LOGFILE"
    echo -e "    LOGFILE\t\t = $LOGFILE" | tee -a "$LOGFILE"
    echo -e "    MINECRAFTCONTAINER\t = $MINECRAFTCONTAINER" | tee -a "$LOGFILE"
    echo -e "    CONTAINERRUNNING?\t = $CONTAINERRUNNING" | tee -a "$LOGFILE"
    echo -e "    INCLUDEFILELIST\t = $INCLUDEFILELIST" | tee -a "$LOGFILE"
    echo -e "    BACKUPSKEEP\t\t = $BACKUPSKEEP" | tee -a "$LOGFILE"

# ====================================================================
# CHECK FOR ALREADY RUNNING JOBS
# ====================================================================
if [[ ! $SKIP_EXISTING_CHECK -eq 1 ]]; then
    echo "[$(date +%Y%m%d-%H%M%S)] Check For Existing Jobs ..." | tee -a "$LOGFILE"
    EXISTING_JOBS=$(ps -eo pid,etimes,etime,command | grep -e "rdiff-backup" | grep -v "grep" | grep -e "minecraft" )
    if [[ ! "$EXISTING_JOBS" == "" ]]; then
        echo "    **ERROR: Found running rdiff-backup Minecraft process - exiting!" | tee -a "$LOGFILE"
        echo "      You can check if conflicting process is still running with:"
        echo "          ps -eo pid,etimes,etime,command | grep -e \"rdiff-backup\" | grep -v \"grep\" | grep -e \"minecraft\""
        exit 1
    else
        echo "    No conflicting jobs found - continuing..."
    fi
else
    echo "[$(date +%Y%m%d-%H%M%S)] Check For Existing Jobs - user specific skip check" | tee -a "$LOGFILE"
fi  

# ====================================================================
# DISABLE CRONTAB JOB
# - NOT REQUIRED SINCE CHECKING FOR ALREADY RUNNING JOBS ANYWAY
# - IF ENABLING, REVIEW CODE AS HASN'T BEEN UPDATED SINCE SCRIPT REWORKED
# ====================================================================
# Disable backup from crontab so that it doesn't re-run while backup already running
#echo "[$(date +%Y%m%d-%H%M%S)] Disabling crontab backup job..." | tee -a "$LOGFILE"
#crontab -l | sed "/^[^#].*minecraft_freq_incremental_backup.sh/s/^/#/" | crontab -
#sed -i '$ s/$/disabled/' $LOGFILE

# ====================================================================
# DISABLE MINECRAFT AUTOSAVE
# ====================================================================
echo "[$(date +%Y%m%d-%H%M%S)] Autosaves - Disabling" | tee -a "$LOGFILE"
if [[ $CONTAINERRUNNING -eq 1 ]]; then
    echo "    Container running - sending autosave disable command"
    docker exec $MINECRAFTCONTAINER rcon-cli save-off
    sed -i '$ s/$/command sent/' $LOGFILE
else
    echo "    Container not running - not sending autosave disable command"
fi

# ====================================================================
# PARSE INCLUDE FILE LIST
# ====================================================================
# Need to parse contents and create args for rdiff-backup since the
# include/exclude needs to have the full source path prefixed and
# since we're using the same list for all backups then we need to
# dynamically process the entries.

INCLUDEARGS=()
IFS=$'\n'
for line in `cat $INCLUDEFILELIST`; do
    if [[ "$line" != "" ]] && [[ "$line" != "#"* ]]; then
        INCLUDEARGS+=("--include '$DIRDATA/$line'")
    fi
done
IFS=''

# ====================================================================
# LOOK FOR WORLD DIRS AND ADD TO INCLUDE LIST
# ====================================================================

while IFS= read -r line; do 
    INCLUDEARGS+=("--include '$line'")
done <<< $(find $DIRDATA -maxdepth 2 -name level.dat | sed 's:[^/]*$::' | sed 's:/*$::')

echo "[$(date +%Y%m%d-%H%M%S)] Parsed 'include' arguments:" | tee -a "$LOGFILE"
echo ${INCLUDEARGS[@]} | tee -a "$LOGFILE"


# ====================================================================
# RDIFF_BACKUP
# ====================================================================
echo "[$(date +%Y%m%d-%H%M%S)] RDIFF-BACKUP" | tee -a "$LOGFILE"

# See include file list for details of what is being included.
# Contents of file will be parsed and used as '--include' args for
# rdiff-backup

RDIFCOMMAND=()
RDIFCOMMAND+=(/usr/bin/rdiff-backup -v5 --force --print-statistics)
RDIFCOMMAND+=(${INCLUDEARGS[@]})
RDIFCOMMAND+=("--exclude '**'")
RDIFCOMMAND+=($DIRDATA)
RDIFCOMMAND+=($DIRBACKUP)


echo "[$(date +%Y%m%d-%H%M%S)] Running rdiff command:" | tee -a "$LOGFILE"
echo ${RDIFCOMMAND[@]} | tee -a "$LOGFILE"

eval "${RDIFCOMMAND[@]}"

echo; echo "[$(date +%Y%m%d-%H%M%S)] BACKUP COMPLETED!" | tee -a "$LOGFILE"


# ====================================================================
# ENABLE MINECRAFT AUTOSAVE
# ====================================================================
echo "[$(date +%Y%m%d-%H%M%S)] Autosaves - Enabling" | tee -a "$LOGFILE"
if [[ $CONTAINERRUNNING -eq 1 ]]; then
    echo "    Container running - sending autosave disable command"
    docker exec $MINECRAFTCONTAINER rcon-cli save-on
    sed -i '$ s/$/command sent/' $LOGFILE
else
    echo "    Container not running - not sending autosave disable command"
fi

# ====================================================================
# ENABLE CRONTAB JOB
# - NOT REQUIRED SINCE CHECKING FOR ALREADY RUNNING JOBS ANYWAY
# - IF ENABLING, REVIEW CODE AS HASN'T BEEN UPDATED SINCE SCRIPT REWORKED
# ====================================================================
# Enable rdiff-backup crontab job
#echo "[$(date +%Y%m%d-%H%M%S)] Enabling crontab backup job..." | tee -a "$LOGFILE"
#crontab -l | sed "/^#.*minecraft_freq_incremental_backup.sh/s/^#//" | crontab -
#sed -i '$ s/$/enabled/' $LOG_LASTRUN

# ====================================================================
# REMOVE FILES OLDER THAN RETENTION PERIOD
# ====================================================================
echo "[$(date +%Y%m%d-%H%M%S)] Deleting old backups (older than $BACKUPSKEEP)..." | tee -a "$LOGFILE"
rdiff-backup --force --remove-older-than $BACKUPSKEEP $DIRBACKUP | tee -a "$LOGFILE"

# ====================================================================
# CONFIRM COMPLETION
# ====================================================================
echo "" | tee -a "$LOGFILE"
echo "[$(date +%Y%m%d-%H%M%S)] Backup Completed" | tee -a "$LOGFILE"
echo
