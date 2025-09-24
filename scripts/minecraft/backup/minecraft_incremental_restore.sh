#!/bin/bash
# shellcheck disable=SC2009,SC2207
echo ""
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
under=$(tput sgr 0 1)
reset=$(tput sgr0)
#isnum='^[0-9]+$'

# To-do
#  Trap early exits due to errors and enable crontab backup job

# Create symlink to this script from the same directory where the minecraft container data file is
# saved: 
# ln -s /home/ryan/scripts/docker/minecraft/backups/minecraft_freq_incremental_restore.sh .

# This script will:
# - Check rdiff-backup not currently running
# - Remove cron job for backup to avoid it running while this script is underway
# - Present a set of dates/timings for 'restore to' state (plus cancel option)
# - Restore files to temp restore directory
# - Read in worlds from temp restore dir
# - Present list of worlds to restore (plus cancel option which also deletes temp restore dir)
# - Backup full data dir (compressed) just in case restore screws something up
# - Stop server container 
# - Move world's files on top of data worlds
# - Delete temp restore dir
# - Add job back to crontab
# - Restart server container 

# Can pass container name as argument #1 if different from default below
# Can also pass world name as argument #2 to skip the world selection menus
# e.g.
# /storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.14 Castaway
# /storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.15
# /storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.15 Castaway
# /storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.15 Epicland
# /storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.16 Epicland
# /storage/Docker/minecraft/itzg/paper_1.16/minecraft_freq_incremental_restore.sh mc_itzg_paper_1.16 Epicland
# /storage/Docker/minecraft/itzg/fabric_1.17/minecraft_freq_incremental_restore.sh mc_itzg_fabric_1.17 Epicland

########################################################
### Function to generate user menus
########################################################

# Function to create a user selectable menu from an array
# https://stackoverflow.com/questions/28325915/create-bash-select-menu-with-array-argument
# Different version also in link which could be tweaked to include extra title and prompt agruments 
createmenu ()
{
    #echo "Size of array: $#"
    #echo "$@"
    select OPTION; do # in "$@" is the default
        if [ "$REPLY" -eq "$#" ]; then   #Exit if response equals last number
        #if [ "$REPLY" -gt "$#" ]; then   #Exit if response is greater than last number
        #if [ "$REPLY" -ge "$#" ]; then   #Exit if response is greater than or equals last number
            echo "${red}Quiting...${reset}"
            echo; exit 1
            #break;
        elif [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#-1)) ]; then
            #echo "You selected $OPTION which is option $REPLY"
            # Add user selections to variables
            VAR_SELECTED_VALUE=$OPTION         
            VAR_SELECTED_NUMBER=$REPLY           # Array is zero indexed so this is index+1
            break;
        else
            echo "Incorrect Input: Select a number 1-$#"
        fi
    done


                            if [[ $DEBUG == 1 ]]; then
                                echo; echo; echo
                                echo "Debugging ++++++++++++++++++++++++++++++++++++++++++"
                                echo "MENU_ARRAY array length = "${#MENU_ARRAY[@]}
                                echo "MENU_ARRAY array elements..."
                                #All elements on single line
                                #echo ${BACKUP_INCREMENTS_RAW[@]}
                                #All elements on new lines:
                                printf "%s\n" "${MENU_ARRAY[@]}"
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo "$VAR_SELECTED_VALUE"
                                echo "$VAR_SELECTED_NUMBER"
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo "Element sourced from BACKUP_INCREMENTS array (should match VAR_SELECTED_VALUE):"
                                echo "    ${BACKUP_INCREMENTS[VAR_SELECTED_NUM-1]}"     # Get value from backup array using user selection
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo; echo; echo
                            fi

}


########################################################
### Set up variables
########################################################

# Set default container name - should also be the name of the container's startup script e.g. mc_itzg_spigot.start
CONTAINER="mc-fabric-epicland"

# Output debug messages?
    DEBUG=1
# Locations
    DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    DIR_DATA="$DIR_SCRIPT/data"
    DIR_BACKUP="$DIR_SCRIPT/backup"
    DIR_RESTORE="$DIR_SCRIPT/restore"
    DIR_ROLLBACK="$DIR_SCRIPT/rollback"
    #DIR_START_SCRIPTS="/home/ryan/scripts/docker/scripts/minecraft/backup/"
    LOG_LASTRUN="$DIR_SCRIPT/lastrun_restore.log"

    DOCKERCOMPOSE_1="/home/rayn/scripts/docker/minecraft.yml"
    DOCKERCOMPOSE_2="/home/rayn/scripts/docker/minecraft_extra.yml"


echo "[$(date +%Y%m%d-%H%M%S)] Starting restore script..." | tee "$LOG_LASTRUN"


########################################################
### HELP TEXT
########################################################

usage()
{
echo ""
echo "${blue}================================================================================================================================="
echo "${green}                          SCRIPT TO RESTORE RECENT MINECRAFT WORLD BACKUPS"
echo "${blue}================================================================================================================================="
echo "${green}"
echo "Create symlink to this script from the same directory where the minecraft container data file is saved:"
echo "${yellow}    ln -s /home/ryan/scripts/docker/minecraft/backups/minecraft_freq_incremental_restore.sh .${green}"
echo ""
echo "Default container if none passed: ${magenta}$CONTAINER${green}"
echo ""
echo "Note: Assumes that server type is part of container name i.e. name contains either 'fabric' or 'paper'. By default will use"
echo "      'fabric' restore method if no type found i.e. will restore 'world' directory."
echo ""
echo "Note: Also assumes that the container name is the same as the 'start' script name. e.g. mc_itzg_paper_1.16 is started by"
echo "      mc_itzg_paper_1.16.start"
echo ""
echo "This script will:"
echo "  - Check rdiff-backup not currently running"
echo "  - Remove cron job for backup to avoid it running while this script is underway"
echo "  - Present a set of dates/timings for 'restore to' state (plus cancel option)"
echo "  - Restore files to temp restore directory"
echo "  - Read in worlds from temp restore dir"
echo "  - Present list of worlds to restore (plus cancel option which also deletes temp restore dir)"
echo "  - Backup full data dir (compressed) just in case restore screws something up"
echo "  - Stop server container "
echo "  - Move world's files on top of data worlds"
echo "  - Delete temp restore dir"
echo "  - Add job back to crontab"
echo "  - Restart server container "
echo ""
echo "${blue}================================================================================================================================="
echo "${cyan}OPTIONAL ARGUMENTS"
echo "${blue}================================================================================================================================="
echo "${cyan}"
echo "#1 - Can pass container name as argument #1 if different from default in script (script default var: ${magenta}$CONTAINER${cyan})"
echo "#2 - If arg #2 set to '${yellow}--latest${cyan}' then manual backup selection will be skipped and the most recent backup will be "
echo "     restored. If specifying '${yellow}--latest${cyan}' then ${under}${cyan}args #1 [and #3 if processing a Paper backup] must also be supplied${reset}${cyan}."
echo "#3 - [if processing Paper backup] Can also pass world name as argument #2/#3 to skip the world selection menus (e.g. ${red}Epicland${cyan})."
echo "     If passing world name then ${under}${cyan}arg #1 must also be given${reset}${cyan}."
echo "${yellow}"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.14/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.14 ${red}Castaway"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.15/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.15"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.15/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.15 ${red}Castaway"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.15/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.15 ${red}Epicland"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.15/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.15 ${yellow}--latest ${red}Epicland"
echo "${cyan}/storage/Docker/minecraft/itzg/paper_1.16/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_paper_1.16 ${yellow}--latest ${red}Epicland"
echo "${cyan}/storage/Docker/minecraft/itzg/fabric_1.17/minecraft_freq_incremental_restore.sh ${magenta}mc_itzg_fabric_1.17_Epicland ${yellow}--latest"
echo "${blue}================================================================================================================================="
echo "${reset}"
}

usage

# Exit if '--help' passed
if [[ $* == *"--help"* ]]; then
  exit
fi


# Use container name if passed as argument - assumes it begins with "mc-", and is first argument
    if [[ $1 == "mc-"* ]]; then 
      echo "[$(date +%Y%m%d-%H%M%S)] Using container name passed on command line: $1 ..." | tee -a "$LOG_LASTRUN"
      CONTAINER=$1; 
    else
      echo "[$(date +%Y%m%d-%H%M%S)] Using container name as defined in script: $CONTAINER ..." | tee -a "$LOG_LASTRUN"
    fi


########################################################
### Check for current backup running
########################################################
    
    # Check that rdiff-backup not currently running
        echo "[$(date +%Y%m%d-%H%M%S)] Checking that no backups are currently underway..." | tee -a "$LOG_LASTRUN"
        EXISTING_JOBS=""
        EXISTING_JOBS=$(ps -eo pid,etimes,etime,command | grep -e rdiff-backup | grep -v "grep")
        if [[ ! "$EXISTING_JOBS" == "" ]]; then
            echo "[$(date +%Y%m%d-%H%M%S)] Backup currently underway - exiting!" | tee -a "$LOG_LASTRUN"
            echo "${red}ERROR - Minecraft backup currently underway wait until it finishes and try again.${reset}"
            echo "${magenta}You can check if it is still running with:"
            echo "    ps -eo pid,etimes,etime,command | grep -e rdiff-backup | grep -v \"grep\"${reset}"
            echo; exit 1
        else 
            echo "[$(date +%Y%m%d-%H%M%S)] ...confirmed no backups currently underway..." | tee -a "$LOG_LASTRUN"
            echo "${green}    ...confirmed no backups currently underway${reset}"; echo
        fi


########################################################
### Parse backup history
########################################################

# Get list of increments in latest backup set
    echo "[$(date +%Y%m%d-%H%M%S)] Getting list of increments in latest backup set..." | tee -a "$LOG_LASTRUN"
    SAVEIFS=$IFS
    IFS=$'\n'
    BACKUP_INCREMENTS=($(rdiff-backup --list-increments "$DIR_BACKUP" | grep -e "    increments" | awk '{$1=""; print}' | awk '{print substr($0,2,length($0)-1)}'))
    IFS=$SAVEIFS

# And add 'current mirror' (latest backup) to list
    CURRENT_MIRROR=$(rdiff-backup --list-increments "$DIR_BACKUP" | grep -e "Current mirror" | awk '{$1=""; $2=""; print}' | awk '{print substr($0,3,length($0)-2)}')
    BACKUP_INCREMENTS+=("$CURRENT_MIRROR")
    #BACKUP_LATEST=${BACKUP_INCREMENTS[-1]}    # Get latest increment from array


                            if [[ $DEBUG == 1 ]]; then
                                echo; echo; echo
                                echo "Debugging ++++++++++++++++++++++++++++++++++++++++++"
                                echo "BACKUP_INCREMENTS array length = "${#BACKUP_INCREMENTS[@]}
                                echo "BACKUP_INCREMENTS array elements..."
                                #All elements on single line
                                #echo ${BACKUP_INCREMENTS_RAW[@]}
                                #All elements on new lines:
                                printf "%s\n" "${BACKUP_INCREMENTS[@]}"
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo; echo; echo
                            fi



########################################################
### Create 1st Menu
########################################################

  
# Check for user supplied 3rd argument
    if [[ $2 == "--latest" ]]; then 
      echo "[$(date +%Y%m%d-%H%M%S)] User specified latest backup, restoring: ${BACKUP_INCREMENTS[-1]}"  | tee -a "$LOG_LASTRUN"
      VAR_SELECTED_VALUE=${BACKUP_INCREMENTS[-1]}
      BACKUP_CHOOSEN=$VAR_SELECTED_VALUE
    fi

# Create menu
  if [[ $2 != "--latest" ]]; then 
    echo "[$(date +%Y%m%d-%H%M%S)] Creating menu of backups..." | tee -a "$LOG_LASTRUN"

    # Pass 10 latest backup increments to menu creator, or all increments if less than 10 available.
    if [[ ${#BACKUP_INCREMENTS[@]} -lt 11 ]]; then
        MENU_ARRAY=("${BACKUP_INCREMENTS[@]}") 
        MENU_ARRAY+=("+++MORE+++ (choose from FULL increment list)")
        MENU_ARRAY+=("Use existing data in $DIR_RESTORE")
        MENU_ARRAY+=("Quit")
    else
        MENU_ARRAY=("${BACKUP_INCREMENTS[-1]}" \
                 "${BACKUP_INCREMENTS[-2]}" \
                 "${BACKUP_INCREMENTS[-3]}" \
                 "${BACKUP_INCREMENTS[-4]}" \
                 "${BACKUP_INCREMENTS[-5]}" \
                 "${BACKUP_INCREMENTS[-6]}" \
                 "${BACKUP_INCREMENTS[-7]}" \
                 "${BACKUP_INCREMENTS[-8]}" \
                 "${BACKUP_INCREMENTS[-9]}" \
                 "${BACKUP_INCREMENTS[-10]}" \
                 "+++MORE+++ (choose from FULL increment list)" \
                 "Use existing data in $DIR_RESTORE")
        MENU_ARRAY+=("Quit")
    fi

# Pass array to createmenu
    echo "${blue}Select backup to restore:${cyan}"
    createmenu "${MENU_ARRAY[@]}"
    BACKUP_CHOOSEN=$VAR_SELECTED_VALUE
    echo "[$(date +%Y%m%d-%H%M%S)] Backup set choosen: $BACKUP_CHOOSEN..." | tee -a "$LOG_LASTRUN"
  fi

########################################################
### Parse response from menu
########################################################

# If response includes substring "+++MORE+++" then create new menu with all options
if [[ $VAR_SELECTED_VALUE == *"+++MORE+++"* ]]; then

    echo "[$(date +%Y%m%d-%H%M%S)] Getting full list of backup increments..." | tee -a "$LOG_LASTRUN"
    ########################################################
    ### 2nd Menu
    ########################################################

    # Clear used array vaables to be reused in new menu
        unset MENU_ARRAY
        unset OPTION
        unset REPLY
        unset VAR_SELECTED_VALUE
        unset VAR_SELECTED_NUMBER 

    # Create new array with extra options before letting user select
        MENU_ARRAY=("${BACKUP_INCREMENTS[@]}")
        MENU_ARRAY+=("Quit")

    # Pass array to createmenu
        echo "${blue}Select backup to restore:${cyan}"
        createmenu "${MENU_ARRAY[@]}"
        BACKUP_CHOOSEN=$VAR_SELECTED_VALUE
       
    # Confirm selection
        echo "[$(date +%Y%m%d-%H%M%S)] Backup set choosen: $BACKUP_CHOOSEN..." | tee -a "$LOG_LASTRUN"
        echo "[$(date +%Y%m%d-%H%M%S)] Will restore $BACKUP_CHOOSEN to staging area ($DIR_RESTORE)..." | tee -a "$LOG_LASTRUN"
                                                                                               
# If response to 1st menu is to use exiting data in restore dir
elif [[ $BACKUP_CHOOSEN == *"existing data"* ]]; then
    echo "[$(date +%Y%m%d-%H%M%S)] Using existing data in $DIR_RESTORE..." | tee -a "$LOG_LASTRUN"
    USE_EXISTING_DATA=1
# If response to 1st menu is a specific increment
else
    echo "[$(date +%Y%m%d-%H%M%S)] Will restore $BACKUP_CHOOSEN to staging area ($DIR_RESTORE)..." | tee -a "$LOG_LASTRUN"
fi


# Perform restore if response to 1st menu was not 'use existing data'
if [[ $USE_EXISTING_DATA != 1 ]]; then

    ########################################################
    ### Disable crontab backup
    ########################################################

    # Check that rdiff-backup not currently running
        echo "[$(date +%Y%m%d-%H%M%S)] Checking that no backups are currently underway..." | tee -a "$LOG_LASTRUN"
        EXISTING_JOBS=""
        EXISTING_JOBS=$(ps -eo pid,etimes,etime,command | grep -e rdiff-backup | grep -v "grep")
        if [[ ! "$EXISTING_JOBS" == "" ]]; then
            echo "[$(date +%Y%m%d-%H%M%S)] Backup currently underway - exiting!" | tee -a "$LOG_LASTRUN"
            echo "${red}ERROR - Minecraft backup currently underway wait until it finishes and try again.${reset}"
            echo "${magenta}You can check if it is still running with:"
            echo "    ps -eo pid,etimes,etime,command | grep -e rdiff-backup | grep -v \"grep\"${reset}"
            echo; exit 1
        else 
            echo "[$(date +%Y%m%d-%H%M%S)] ...confirmed no backups currently underway..." | tee -a "$LOG_LASTRUN"
            echo "${green}    ...confirmed no backups currently underway${reset}"
        fi

    # Disable minecraft_incremental_backup.sh from crontab so that it doesn't run while restore is running
        echo "[$(date +%Y%m%d-%H%M%S)] Disabling crontab backup job..." | tee -a "$LOG_LASTRUN"
        # Debugging pause
        if [[ $DEBUG == 1 ]]; then
            read -r -p "Press key to continue..."
        fi
        crontab -l | sed "/^[^#].*minecraft_incremental_backup.sh/s/^/#/" | crontab -
        echo "${red}    ...disabled${reset}"


    ########################################################
    ### Restore backup to restore staging directory
    ########################################################

    # Create staging dir if it doesn't exist
    if [[ ! -d "$DIR_RESTORE" ]]; then
        echo "[$(date +%Y%m%d-%H%M%S)] Staging dir not found, creating: $DIR_RESTORE..." | tee -a "$LOG_LASTRUN"
        mkdir "$DIR_RESTORE"
    fi

    # Delete existing data in restore dir
        echo "[$(date +%Y%m%d-%H%M%S)] Deleting existing data in staging directory..." | tee -a "$LOG_LASTRUN"
        # Debugging pause
        if [[ $DEBUG == 1 ]]; then
            read -r -p "Press key to continue..."
        fi
        rm -r "$DIR_RESTORE"
        echo "${red}    ...deleted${reset}"

    # Restore to restore dir
        echo "[$(date +%Y%m%d-%H%M%S)] Restoring backup to staging directory..." | tee -a "$LOG_LASTRUN"
        # Debugging pause
        if [[ $DEBUG == 1 ]]; then
            read -r -p "Press key to continue..."
        fi
        rdiff-backup --restore-as-of "$BACKUP_CHOOSEN" "$DIR_BACKUP/$BACKUP_SET_LATEST" "$DIR_RESTORE/"
        touch "$DIR_RESTORE/.nobackup"    # Add flag for duplicacy to skip folder
        echo "${green}!! BACKUP ($BACKUP_CHOOSEN) RESTORED !!${reset}"

fi


########################################################
### Provide user list of worlds to restore
########################################################

# Check if fabric or paper server - assuming reflected in container name
# if 'paper' then process world names, otherwise assume world is called 'world'
if [[ $CONTAINER == *"paper"* ]]; then 

    echo "[$(date +%Y%m%d-%H%M%S)] Paper container being processed - checking for worlds..." | tee -a "$LOG_LASTRUN"

    # Check for world name passed as second argument to skip interaction with user
    if [[ -n "$3" ]]; then
        echo "[$(date +%Y%m%d-%H%M%S)] World name passed directly in command line: $3 ..." | tee -a "$LOG_LASTRUN"
        WORLD=$3
        WORLD_NETHER=$WORLD"_nether"
        WORLD_END=$WORLD"_the_end"
    elif [[ -n "$2" ]] && [[ $2 != "--latest" ]]; then
        echo "[$(date +%Y%m%d-%H%M%S)] World name passed directly in command line: $2 ..." | tee -a "$LOG_LASTRUN"
        WORLD=$3
        WORLD_NETHER=$WORLD"_nether"
        WORLD_END=$WORLD"_the_end"
    else
    
        echo "[$(date +%Y%m%d-%H%M%S)] Analysing data in staging directory to find worlds..." | tee -a "$LOG_LASTRUN"
        
        # Set list of directory naames that we don't want returned in our world list
            WORLDS_EXCLUDE="config \
                            cache \
                            crash-reports \
                            logs \
                            mods \
                            plugins"
        
        # Get list of worlds from restored file set
        echo "[$(date +%Y%m%d-%H%M%S)] Getting list of worlds from restored file set..." | tee -a "$LOG_LASTRUN"
            declare -a WORLD_LIST
            for files in $DIR_RESTORE/* ; do
                if [[ -d $files ]]; then
                    file=$(basename "$files")
                    echo "${yellow}Checking $file...${reset}"    #Debugging
                    if [[ "$WORLDS_EXCLUDE" == *"$file"* || "$file" == *"_nether" || "$file" == *"_the_end" ]]; then
                        echo "${magenta}    ...skipping $file${reset}"
                    else
                        echo "${green}    ...$file found${reset}"
                        WORLD_LIST+=("$file")
                    fi
                fi
            done
        
                            if [[ $DEBUG == 1 ]]; then
                                echo; echo; echo
                                echo "Debugging ++++++++++++++++++++++++++++++++++++++++++"
                                echo "$WORLDS_EXCLUDE"
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo "WORLD_LIST array length = "${#WORLD_LIST[@]}
                                echo "WORLD_LIST array elements..."
                                #All elements on single line
                                #echo ${WORLD_LIST[@]}
                                #All elements on new lines:
                                printf "%s\n" "${WORLD_LIST[@]}"
                                echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
                                echo; echo; echo
                            fi
        echo "[$(date +%Y%m%d-%H%M%S)] Creating menu of worlds..." | tee -a "$LOG_LASTRUN"
        # Clear array used for menu & selected options in case createmenu used again
            unset MENU_ARRAY
            unset OPTION
            unset REPLY
            unset VAR_SELECTED_VALUE
            unset VAR_SELECTED_NUMBER
        
        # Select what to restore
            MENU_ARRAY=("${WORLD_LIST[@]}")
            MENU_ARRAY+=("Cancel & Quit")
        
        # Pass array to createmenu
            echo
            echo "${blue}Select world to restore (Nether and End will also be restored if available)...${cyan}"
            createmenu "${MENU_ARRAY[@]}"
            WORLD=$VAR_SELECTED_VALUE
            WORLD_NETHER=$WORLD"_nether"
            WORLD_END=$WORLD"_the_end"
            echo "[$(date +%Y%m%d-%H%M%S)] World to restore: $WORLD..." | tee -a "$LOG_LASTRUN"
    
        # Give user chance to cancel in case they made a mistake
        #    echo
        #    read -r -p "`echo -e $'\e[0;35m'`Are you sure you want to restore $WORLD? [y/N] `echo -e $'\n\e[0m'`" response
        #    response=${response:-No}    # Default response
        #    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        #    else
        #        echo "${red}Quitting${reset}"
        #        echo; exit 1
        #    fi
    
    fi

# Else assume world is called 'world'
else
    echo "[$(date +%Y%m%d-%H%M%S)] Non-Paper container being processed..." | tee -a "$LOG_LASTRUN"
    WORLD="world"
    echo "[$(date +%Y%m%d-%H%M%S)] World to restore: $WORLD..." | tee -a "$LOG_LASTRUN"
fi


# Stop server
    echo "[$(date +%Y%m%d-%H%M%S)] Stopping Minecraft server..." | tee -a "$LOG_LASTRUN"
    # Debugging pause
    if [[ $DEBUG == 1 ]]; then
        read -r -p "Press key to continue..."
    fi
    docker rm -f -v "$CONTAINER"
    echo "${red}    ...stopped${reset}"

# Make copy of existing files for potential rollback of restore
    echo "[$(date +%Y%m%d-%H%M%S)] Making copy of existing world data for rollback of restore if needed..." | tee -a "$LOG_LASTRUN"
    # Debugging pause
    if [[ $DEBUG == 1 ]]; then
        read -r -p "Press key to continue..."
    fi
    
    # Create rollback dir if it doesn't exist
    if [[ ! -d "$DIR_ROLLBACK" ]]; then
        echo "[$(date +%Y%m%d-%H%M%S)] Rollback dir not found, creating: $DIR_ROLLBACK..." | tee -a "$LOG_LASTRUN"
        mkdir "$DIR_ROLLBACK"
    fi

    # Make roolback copy
    # Originally datestamped the copies so we could rollback to any previously overwritten world.
    # Switched to single copy since we ended up with a lot of data in this dir. Datestampe cmds
    # retained below in case needed.
    if [[ -d "$DIR_DATA/$WORLD" ]]; then
        #cp -r $DIR_DATA/$WORLD $DIR_ROLLBACK/$WORLD[$DATESTAMP]
        cp -r "$DIR_DATA/$WORLD" "$DIR_ROLLBACK/$WORLD"
    else 
        echo "${red}ERROR - $DIR_DATA/$WORLD not found - exiting!${reset}"
        echo; exit 1
    fi
    if [[ -d "$DIR_DATA/$WORLD_NETHER" ]]; then
        #cp -r $DIR_DATA/$WORLD_NETHER $DIR_ROLLBACK/$WORLD_NETHER[$DATESTAMP]
        cp -r "$DIR_DATA/$WORLD_NETHER" "$DIR_ROLLBACK/$WORLD_NETHER"
    else 
        echo "${magenta}Note - separate $DIR_RESTORE/$WORLD_NETHER not found - not saving copy of current data${reset}"
    fi
    if [[ -d "$DIR_DATA/$WORLD_END" ]]; then
        #cp -r $DIR_DATA/$WORLD_END $DIR_ROLLBACK/$WORLD_END[$DATESTAMP]
        cp -r "$DIR_DATA/$WORLD_END" "$DIR_ROLLBACK/$WORLD_END"
    else 
        echo "${magenta}Note - separate $DIR_RESTORE/$WORLD_END not found - not saving copy of current data${reset}"
    fi
    echo "${yellow}    ...completed${reset}"

# Delete existing world files in minecraft data dir
    echo "[$(date +%Y%m%d-%H%M%S)] Deleting world from Minecraft data dir..." | tee -a "$LOG_LASTRUN"
    # Debugging pause
    if [[ $DEBUG == 1 ]]; then
        read -r -p "Press key to continue..."
    fi
    # Delete data
    if [[ -d "$DIR_DATA/$WORLD" ]]; then
       rm -r "${DIR_DATA:?}/$WORLD"
    fi
    if [[ -d "$DIR_DATA/$WORLD_NETHER" ]]; then
        rm -r "${DIR_DATA:?}/$WORLD_NETHER"
    fi
    if [[ -d "$DIR_DATA/$WORLD_END" ]]; then
        rm -r "${DIR_DATA:?}/$WORLD_END"
    fi
    echo "${yellow}    ...completed${reset}"

# Copy file to minecraft data dir
    echo "[$(date +%Y%m%d-%H%M%S)] Copying world from staging directory to Minecraft data dir..." | tee -a "$LOG_LASTRUN"
    # Debugging pause
    if [[ $DEBUG == 1 ]]; then
        read -r -p "Press key to continue..."
    fi
    # Copy data
    if [[ -d "$DIR_RESTORE/$WORLD" ]]; then
        cp -r "$DIR_RESTORE/$WORLD" "$DIR_DATA/$WORLD"
    else 
        echo "${red}ERROR - $DIR_RESTORE/$WORLD not found${reset}"
        echo "${red}Quitting [note that crontab backup job not re-enabled yet]${reset}"
        echo; exit 1
    fi
    if [[ -d "$DIR_RESTORE/$WORLD_NETHER" ]]; then
        cp -r "$DIR_RESTORE/$WORLD_NETHER" "$DIR_DATA/$WORLD_NETHER"
    else 
        echo "${magenta}Note - $DIR_RESTORE/$WORLD_NETHER not found, not restoring separate Paper Nether dir${reset}"
    fi
    if [[ -d "$DIR_RESTORE/$WORLD_END" ]]; then
        cp -r "$DIR_RESTORE/$WORLD_END" "$DIR_DATA/$WORLD_END"
    else 
        echo "${magenta}Note - $DIR_RESTORE/$WORLD_END not found, not restoring separate Paper End dir${reset}"
    fi
    echo "${green}!! WORLD DATA RESTORED !!"


########################################################
### Re-enable crontab backup & restart server
########################################################

    # Enable rdiff-backup crontab job
        echo "[$(date +%Y%m%d-%H%M%S)] Enabling crontab backup job..." | tee -a "$LOG_LASTRUN"
        # Debugging pause
        if [[ $DEBUG == 1 ]]; then
            read -r -p "Press key to continue..."
        fi
        crontab -l | sed "/^#.*minecraft_incremental_backup.sh/s/^#//" | crontab -
        echo "${green}    ...enabled${reset}"

    # Restart server
    echo "[$(date +%Y%m%d-%H%M%S)] Starting Minecraft server..." | tee -a "$LOG_LASTRUN"
        # Debugging pause
        if [[ $DEBUG == 1 ]]; then
            read -r -p "Press key to continue..."
        fi
        #$DIR_START_SCRIPTS/$CONTAINER.start

        if grep -q "$CONTAINER" $DOCKERCOMPOSE_1; then
            docker compose -f $DOCKERCOMPOSE_1 up -d --force-recreate "$CONTAINER"
        elif grep -q "$CONTAINER" $DOCKERCOMPOSE_2; then
            docker compose -f $DOCKERCOMPOSE_2 up -d --force-recreate "$CONTAINER"
        else
            echo "${red}ERROR - Can't find service in docker-compose files. Restart manually!${reset}"
            echo; exit 1
        fi

        echo "${green}    ...started${reset}"


########################################################
### Notify user and log of completion
########################################################
echo
echo "${green}!! RESTORE JOB COMPLETED !!"
echo "${yellow}Note: overwritten files copied to $DIR_ROLLBACK${reset}"
echo "${red}... wait 1 minute for server to complete restart ...${reset}"
echo

echo "[$(date +%Y%m%d-%H%M%S)] Completed!" | tee -a "$LOG_LASTRUN"