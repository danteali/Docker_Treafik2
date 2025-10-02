#!/bin/bash
    red=`tput setaf 1`
    green=`tput setaf 2`
    yellow=`tput setaf 3`
    blue=`tput setaf 4`
    magenta=`tput setaf 5`
    cyan=`tput setaf 6`
    under=`tput sgr 0 1`
    reset=`tput sgr0`

## ADD CUSTOM ANNOTATIONS TO GRAFANA

# Using annotation API we can create annotationsin Grafana.
# https://grafana.com/docs/grafana/latest/http_api/annotations/
#
# JSON to be sent (order not important):
#        {
#          "dashboardId":468,               # Numeric
#          "panelId":1,                     # Numeric
#          "time":1507037197339,            # Numeric
#          "timeEnd":1507180805056,         # Numeric
#          "tags":["tag1","tag2"],          # String - comma separated
#          "text":"Annotation Description"  # String
#        }
# Can quickly/easily be converted to 1-line string using Sublime's Pretty JSON Package to 'Minify' JSON, which gives:
#        {"dashboardId":468,"panelId":1,"time":1507037197339,"timeEnd":1507180805056,"tags":["tag1","tag2"],"text":"Annotation Description"}
#
# TIME
# - Time should be in epoch seconds multiplied by 100 to get milliseconds.
#   Or can be generated with: 
#        date +%s%N | cut -b1-13
#
# - Can convert milliseconds back to human readable with: 
#        date -d @$(  echo "(1641057780000 + 500) / 1000" | bc)
#
# DASH/PANEL IDs
#  - Dashboard and panel IDs are optional. These can be left empty.
#    If provided they must be numbers, not strings
#    These IDs can be found in the Grafana Exports using other script, or generated using API with:
#
# CURL
# To be sent to Grafana using curl:
#        curl -X POST http://admin:Aaeire5813M0r17hgR@192.168.0.10:7000/api/annotations -H 'Content-Type: application/json' -d '{"dashboardId":7,"panelId":9,"time":1640978100000,"timeEnd":1640978100000,"tags":["custom"],"text":"Test 5 - 31/12 1915 - 1000 multiplier, start end identical, tagged, dash = host (id: 7), panel = CPU Load (id:9)"}'
#
# Or with variables and additional curl options:
#   -f = --fail = Fail silently (no output at all) on server errors
#   -s = --silent = Don't show progress meter or error messages
#   -L = --location = If the server reports that the requested page has moved to a different location (indicated with a Location: header and a 3XX response code), this option will make curl redo the request on the new place.
#   -S = --show-error = When used with -s, --silent, it makes curl show an error message if it fails.
#   -k = --insecure = By default, every SSL connection curl makes is verified to be secure. This option allows curl to proceed and operate even for server connections otherwise considered insecure.
#
#       curl -sSL -f -k -X POST "${HOST}/api/annotations" /
#           -H 'Content-Type: application/json' /
#           -d '$MESSAGE'



SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

## Get info from .conf file
typeset -A secrets    # Define array to hold variables 
while read line; do
  if echo $line | grep -F = &>/dev/null; then
    varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
  fi
done < $SCRIPT_DIR/grafana_annotations.conf
#echo ${secrets[USERNAME]}; echo ${secrets[PASSWORD]}; echo ${secrets[IP]}; echo ${secrets[PORT]}


## Variables
# Grafana URL
USERNAME="${secrets[USERNAME]}"
PASSWORD="${secrets[PASSWORD]}"
IP="${secrets[IP]}"
PORT=${secrets[PORT]}
HOST="http://$USERNAME:$PASSWORD@$IP:$PORT"
# Note, instead of username/password we can create an API key in Configuration > API keys and access API with:
#   curl -H "Authorization: Bearer <paste key here>" https://play.grafana.com/api/search

# JSON INPUT
ID_DASH=0
ID_PANEL=0
TAGS=""
TIME_START=0
TIME_END=0
COMMENT=""
TAG_DEFAULT="misc"

# Regex - to tes if var is a number below
isnum='^[0-9]+$'



# Function to get Grafana Dashboard and Panel IDs
# Called from input parsing section below.
get_ids() {

    # OUTPUT FILES
    FILE_DASH_LIST="$SCRIPT_DIR/dashboard_list.txt"
    FILE_DASHPANEL_IDS="$SCRIPT_DIR/dashboard_panel_ids.txt"
    FILE_DASHPANEL_IDS_OLD="$SCRIPT_DIR/dashboard_panel_ids.old"
    
    # TEMP FILES
    DIR_TEMP=$SCRIPT_DIR/temp
    mkdir -p $DIR_TEMP
    FILE_TEMP_DASH_KEYINFO="$DIR_TEMP/_dashboards_key_info.txt"
    FILE_TEMP_PANEL_PARSE="$DIR_TEMP/panel_parse.txt"
    
    # 'Backup' old output file, and prep empty file for output
    cp $FILE_DASHPANEL_IDS $FILE_DASHPANEL_IDS_OLD
    echo "SETUP NICE PRINTF TABLE????" > $FILE_DASHPANEL_IDS
    echo "" >> $FILE_DASHPANEL_IDS

    echo; echo; echo "ANALYSING DASHBOARDS ...";
    
        #==== Grab summary dashboard data and get UIDs to use to export full dashboard info:
        echo "Requesting summary dashboard info from Grafana ..."
        curl -sSL -f -k "${HOST}/api/search?query=&" | \
            jq -r "if type==\"array\" then .[] else . end" | \
            tee $FILE_DASH_LIST  >/dev/null
    
        #==== Parse dashboard data into useable fields:
        echo "Extracting key data from Grafana response ..."
        cat $FILE_DASH_LIST | \
            jq -r "[.title, .uid, .type, .folderTitle, .id] | @csv" | \
            tee $FILE_TEMP_DASH_KEYINFO >/dev/null
    
    
        #==== For each record:
        #====   - check if it's a dashboard (not a folder) and grab dashboard data
        echo "Requesting specific dashboard info from Grafana ..."
        while IFS="," read -r REC_TITLE REC_UID REC_TYPE REC_FOLDERTITLE REC_ID
        do
            # Remove quotes from string
            REC_TITLE=$(echo $REC_TITLE | tr -d '"')
            REC_UID=$(echo $REC_UID | tr -d '"')
            REC_TYPE=$(echo $REC_TYPE | tr -d '"')
            REC_FOLDERTITLE=$(echo $REC_FOLDERTITLE | tr -d '"')
            REC_ID=$(echo $REC_ID | tr -d '"')
    
            echo -e "\nParsing:"
            echo -e "\tDashboard Title = \t $REC_TITLE"
            echo -e "\tUID = \t\t\t $REC_UID"
            echo -e "\tType = \t\t\t $REC_TYPE"
            echo -e "\tFolder Title = \t\t $REC_FOLDERTITLE"
            echo -e "\tID = \t\t\t $REC_ID"
    
            # If type = dash-folder ignore
            #if [[ $REC_TYPE = "dash-folder" ]]; then
            
            # If type = dash-db, then:
            # - grab full dashboard data, save in tmp file
            # - parse dashboard data to get panel info
            # - update output file with any dashboard & panel info
            if [[ $REC_TYPE = "dash-db" ]]; then
    
                # Create dashboard folder in temp dir to hold dashboard extract (if it doesn't exist)
                mkdir -p "$DIR_TEMP/$REC_FOLDERTITLE"
    
                # Grab full dashboard data, save in tmp file
                curl -sSL -f -k "${HOST}/api/dashboards/uid/$REC_UID" | \
                    jq -r '.[]' | \
                    tee "$DIR_TEMP/$REC_FOLDERTITLE/$REC_TITLE.json"  >/dev/null
    
                # Note that we're not deleting some of the dash data that we would usually do in 'exporter' script sas we don;t need these files to be importable later
                # jq  'del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' | \
    
                # Parse dashboard data to get panel info
                cat "$DIR_TEMP/$REC_FOLDERTITLE/$REC_TITLE.json" | \
                    jq -r '.. | objects | select(has("id")) | select(has("title")) | select(has("type")) | [.title, .id, .type] | @csv' | \
                    tee $FILE_TEMP_PANEL_PARSE  >/dev/null
    
                # Or could use jq command:
                # jq -r 'getpath( paths(has("id")?)) | [.title, .id, .type] | @csv'
    
    
                
                # Update output file with Dashboard info
                echo -e "\nWriting dashboard and panel info to output file:"
                echo -e "\n$REC_TITLE" | tee -a $FILE_DASHPANEL_IDS
                echo -e "\tID: $REC_ID" | tee -a $FILE_DASHPANEL_IDS
                echo -e "\tFolder: $REC_FOLDERTITLE" | tee -a $FILE_DASHPANEL_IDS
                echo -e "\tUID: $REC_UID" | tee -a $FILE_DASHPANEL_IDS
    
                # Parse panel output and save in output file
                while IFS="," read -r PANEL_TITLE PANEL_ID PANEL_TYPE
                do
    
                    # Remove quotes from string
                    PANEL_TITLE=$(echo $PANEL_TITLE | tr -d '"')
                    PANEL_ID=$(echo $PANEL_ID | tr -d '"')
                    PANEL_TYPE=$(echo $PANEL_TYPE | tr -d '"')
                    
                    if [[ $PANEL_TYPE != "row" ]] && [[ $PANEL_TYPE != "dashboards" ]]; then
                        echo -e "\t\t(ID: $PANEL_ID) $PANEL_TITLE [$PANEL_TYPE]" | tee -a $FILE_DASHPANEL_IDS
                    fi
    
                done < "$FILE_TEMP_PANEL_PARSE"
    
            else
                echo "DASHBOARD TYPE ($REC_TYPE) NOT dash-db ... SKIPPING"
    
            fi
    
        done < "$FILE_TEMP_DASH_KEYINFO"
        rm -r "$DIR_TEMP"
    
    echo -e "\n\nDashboard and Panel IDs saved in:"
    echo -e"\t$FILE_DASHPANEL_IDS"
    exit 0
}


# Parse agruments - args can be passed in any order
    # Parse agrs for provided values
    while test $# -gt 0; do
      case "$1" in
        -h|--help)
          echo
          echo "GRAFANA ANNOTATIONS"
          echo " "
          echo "Usage: $0 [-l] -c \"TEXT\" [-s TIME] [-s TIME] [-t \"TEXT\"] [-d INT] [-p INT]" 
          echo " "
          echo "options:"
          echo "-h, --help                                               show help"
          echo "-l, --list                                               generate dashboard and panel ID list - saved in dashboard_panel_ids.txt"
          echo "-c \"TEXT\" -c=\"TEXT\" --comment \"TEXT\" --comment=\"TEXT\"    specify commentary TEXT for annotation [MANDATORY]"
          echo "-s TIME   -s=TIME   --start TIME     --start=TIME        specify TIME for annotation start (see notes below)"
          echo "-e TIME   -e=TIME   --end TIME       --end=TIME          specify TIME for annotation end (see notes below)"
          echo "-t \"TEXT\" -t=\"TEXT\" --tags \"TEXT\"    --tags=\"TEXT\"       specify comma separated tags for the annotation"
          echo "-d INT    -d=INT    --dashboard INT  --dashboard=INT     specify dashboard ID"
          echo "-p INT    -p=INT    --panel INT      --panel=INT         specify panel ID [default 0 - see notes below]"
          echo
          echo "Annotations get stored in '--Grafana--' dataset. The dataset can be configured to display annotations with specific tags,"
          echo "or annotations based on dashboard/panel IDs specified in command."
          echo 
          echo "DASHBOARD / PANEL IDs"
          echo "Dashboard and panel IDs can be specified (run command with -l,--list flag to generate list of IDs). Annotations will then be"
          echo "shown against the corresponding dash/panel. The '--Grafana--' dataset must be setup to display annotations based on 'Dashboard'"
          echo "Panel ID is 0 if not specified, this will display annotation against all panels in a specific Dashboard."
          echo
          echo "TAGS"
          echo "Tags are not mandatory as dashboard/panel IDs can instead be used instead to specify where an annotation should be shown."
          echo "But if a tag has not been defined, and no dashboard ID is specified then script will use default tag ($TAG_DEFAULT)."
          echo "Must be comma separated if multiple provided."
          echo
          echo "START TIME"
          echo "Time can be specified as anything that 'date' command recognises, or as linux epoch seconds/milliseconds (the script compares"
          echo "length of any integer provided to determine whether it thinks seconds or milliseconds have been provided)."
          echo "Or if not specified, the current time will be used."
          echo "END TIME"
          echo "Same format as start time. Will be set to match start time if no value provided."
          echo
          echo "Linux epoch seconds:         date +%s"
          echo "Linux epoch milliseconds:    date +%s%N | cut -b1-13"
          echo "Common 'date' formats:       yyyymmdd hh:mm:ss, X minutes ago, X days ago, next mon, ..."
          echo 
          echo "EXAMPLES"
          echo "Annotation: System Restart - 5 min ago - Dashboard: Host - Panel: CPU Load - Tags: system, power"
          echo "    $0 -c \"System Restarted\" -s \"5 min ago\" -t \"system,power\" -d 7 -p 9"
          echo
          echo "Annotation: Backup Complete - now - No specific dash/panel - No specified tags (default '$TAG_DEFAULT') will be used"
          echo "    $0 -c \"Backup Complete\""
          echo
          exit 0
          ;;



        # LIST IDs
        -l|--list)
          get_ids
          exit 0
          ;;

        # START TIME
        -s=*|--start=*)
          TIME_START=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -s|--start)
          shift
          if test $# -gt 0; then
            TIME_START=$1
          else
            echo "no start time specified"
            exit 1
          fi
          shift
          ;;

        # END TIME
        -e=*|--end=*)
          TIME_START=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -e|--end)
          shift
          if test $# -gt 0; then
            TIME_END=$1
          else
            echo "no start time specified"
            exit 1
          fi
          shift
          ;;

        # TAGS
        -t=*|--tags=*)
          TAGS=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -t|--tags)
          shift
          if test $# -gt 0; then
            TAGS=$1
          else
            echo "no tags specified (comma separated)"
            exit 1
          fi
          shift
          ;;

        # COMMENT
        -c=*|--comment=*)
          COMMENT=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -c|--comment)
          shift
          if test $# -gt 0; then
            COMMENT=$1
          else
            echo "no comment text specified"
            exit 1
          fi
          shift
          ;;

        # DASH ID
        -d=*|--dashboard=*)
          ID_DASH=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -d|--dashboard)
          shift
          if test $1 -eq 0; then
            echo "0 is an invalid dashboard ID"
            exit 1
          fi
          if test $# -gt 0; then
            ID_DASH=$1
          else
            echo "no dashboard ID specified"
            exit 1
          fi
          shift
          ;;

        # PANEL ID
        -p=*|--panel=*)
          ID_PANEL=`echo $1 | sed -e 's/^[^=]*=//g'`
          shift
          ;;
        -p|--panel)
          shift
          if test $# -gt 0; then
            ID_PANEL=$1
          else
            echo "no panel ID specified"
            exit 1
          fi
          shift
          ;;


        *)
          break
          ;;
      esac
    done
    

# PROCESS SOME OF THE VARIABLES
    
# COMMENTS - Exit if not provided
    if [[ $COMMENT = "" ]]; then echo "Comment not provided. Exiting!"; exit 1; fi
    
# TAGS
    # Apply defulat tag if no dash IDs specified (panel can stay at defulat 0)
    if [[ $ID_DASH = 0 ]]; then
        if [[ $TAGS = "" ]]; then
            echo "TAGS: No dashboard/panel IDs specified. No tags defined - applying default ($TAG_DEFAULT)."
            TAGS=$TAG_DEFAULT
        fi
    fi

    # PARSE TAGS INTO COMMA SEPARATED STRING ARRAY
    # - Replace , with ","
    TAGS=$(echo "$TAGS" | sed -r 's/[,]+/","/g')
    # - Add " to start and end
    TAGS=$(echo "\"$TAGS\"")


# Maybe implement:
# Test for ':' and convert yyyymmdd hh:mm:ss to epcoh/millis???
# Will this work with string/number switching in variable?

# PARSE TIMING
# Start:
# - If no start time provided get current time (millis)
    if [[ $TIME_START = 0 ]]; then
        echo "START TIME: Start time not specified - using current time."
        TIME_START=$(date +%s%N | cut -b1-13)
#   Otherwise check it's a number then check length to see if epoch or millis - convert epoch to millis if needed
    elif [[ $TIME_START =~ $isnum ]]; then
        if [[ ${#TIME_START} -lt 11 ]]; then
            TIME_START_HUMAN=$(date -d @$TIME_START +"%Y-%m-%d %H:%M:%S")
            echo "START TIME: Start time length indicates in epoch format ($TIME_START_HUMAN) - converting to milliseconds."
            TIME_START=$(( 1000*TIME_START ))
        else
            TIME_START_HUMAN=$(date -d @$(  echo "($TIME_START + 500) / 1000" | bc) +"%Y-%m-%d %H:%M:%S")
            echo "START TIME: Start time length indicates already in milliseconds format ($TIME_START_HUMAN) - using provided value."
        fi
# If time not a number then assume user passed string recognisable by 'date', convert to epoch and millis
    else 
        echo "START TIME: Start time provided in string format - attempting to convert to milliseonds."
        TIME_START=$(date --date="$TIME_START" +"%s")
        TIME_START=$(( 1000*TIME_START ))
    fi

# End:
# - If no end time, match start time
    if [[ $TIME_END = 0 ]]; then
        TIME_END=$TIME_START
        echo "END TIME: End time not specified - matching start time."
#   Otherwise check it's a number then check length to see if epoch or millis - convert epoch to millis if needed
    elif [[ $TIME_END =~ $isnum ]]; then
        if [[ ${#TIME_END} -lt 11 ]]; then
            TIME_END_HUMAN=$(date -d @$TIME_END +"%Y-%m-%d %H:%M:%S")
            echo "END TIME: End time length indicates in epoch format ($TIME_END_HUMAN) - converting to milliseconds."
            TIME_END=$(( 1000*TIME_END ))
        else
            TIME_END_HUMAN=$(date -d @$(  echo "($TIME_END + 500) / 1000" | bc) +"%Y-%m-%d %H:%M:%S")
            echo "END TIME: End time length indicates already in milliseconds format ($TIME_END_HUMAN) - using provided value."
        fi
# If time not a number then assume user passed string recognisable by 'date', convert to epoch and millis
    else
        echo "END TIME: End time provided in string format - attempting to convert to milliseonds."
        TIME_END=$(date --date="$TIME_END" +"%s")
        TIME_END=$(( 1000*TIME_END ))
    fi




# SEND COMMAND

TIME_START_HUMAN=$(date -d @$(  echo "($TIME_START + 500) / 1000" | bc) +"%Y-%m-%d %H:%M:%S")
TIME_END_HUMAN=$(date -d @$(  echo "($TIME_END + 500) / 1000" | bc) +"%Y-%m-%d %H:%M:%S")


# Prepare JSON

    JSON="{\"time\":$TIME_START,\"timeEnd\":$TIME_END,\"text\":\"$COMMENT\""

    # Add tags to JSON if not ""
    if [[ $TAGS != "\"\"" ]]; then
        JSON="$JSON,\"tags\":[$TAGS]"
    fi

    # Add dash/panel ID to JSON if dash ID not 0 (panel ID can be zero)
    if [[ $ID_DASH != 0 ]]; then
        JSON="$JSON,\"dashboardId\":$ID_DASH,\"panelId\":$ID_PANEL"
    fi

    JSON="$JSON}"


# Output variables for info
    echo
    echo "SUMMARY DATA:"
    echo -e "\tDashboard ID: \t$ID_DASH"
    echo -e "\tPanel ID: \t$ID_PANEL"
    echo -e "\tTags: \t\t$TAGS"
    echo -e "\tTime - Start: \t$TIME_START ($TIME_START_HUMAN)"
    echo -e "\tTime - End: \t$TIME_END ($TIME_END_HUMAN)"
    echo -e "\tComment: \t$COMMENT"
    echo ""
    echo -e "Sending JSON message:"
    echo -e "\t$JSON"
    echo

curl -sSL -f -k -X POST "${HOST}/api/annotations" \
    -H 'Content-Type: application/json' \
    -d "$JSON"

echo
echo "done"

exit



