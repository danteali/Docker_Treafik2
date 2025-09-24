#!/bin/bash
# shellcheck disable=SC2116,SC2155
set -o pipefail -o nounset
#pipefail = return value of a pipeline is the value of the last (rightmost) command to exit with a
#   non-zero status, or zero if all commands in the pipeline exit successfully.
#nounset = exits if any of your variables are not set.

GRAFANAEXPORTDEBUGGING=1

### NOTES: CURL & JQ #################################################################################################
# Main curl command we use to grab data from Grafana is similar in structure to:
#   curl -sSL -f -k "${GRAFANAEXPORTHOST}/api/${1}" | jq -r "if type==\"array\" then .[] else . end | [.title, .uri] | @csv"
# Or with an API key:
#   curl -sSL -f -k -H "Authorization: Bearer <paste token here>" "${GRAFANAEXPORTHOST}/api/${1}" | jq -r "if type==\"array\" then .[] else . end | [.title, .uri] | @csv"
#
# 'curl' use:
#   -f = --fail = Fail silently (no output at all) on server errors
#   -s = --silent = Don't show progress meter or error messages
#   -L = --location = If the server reports that the requested page has moved to a different location (indicated with a Location: header and a 3XX response code), this option will make curl redo the request on the new place.
#   -S = --show-error = When used with -s, --silent, it makes curl show an error message if it fails.
#   -k = --insecure = By default, every SSL connection curl makes is verified to be secure. This option allows curl to proceed and operate even for server connections otherwise considered insecure.
#
# 'jq' use:
#   -r = raw output
#   if statement simply checks if output is an array and either selects all array content (.[]) or all non-array content (.) so that we have consistent format for next step.
#   '|' = pipes 'if' output and selects fields e.g. title and uri fields
#   '@csv' = processes fields as comma separated so that they are all on one line and can then be processed further to work on each field. 
#            jq also adds quotes around each field in case they conatin a comma.
#            Excellent guide on processing CSV files: https://www.baeldung.com/linux/csv-parsing
# 

### SETUP VARIABLES #################################################################################################

initial-vars() {

    ###############################################################################
    # PREVIOUSLY USED A CONF FILE FOR TARGET PARAMETERS 
    # See archived script version history for previous scripts using this approach
    ###############################################################################

    ### CONF FILE VARIABLES 
    ## Get info from .conf file
    CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    typeset -A secrets    # Define array to hold variables 
    while read -r line; do
    if echo "$line" | grep -F = &>/dev/null; then
        varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
    done < "$CONF_DIR/exporter.conf"
    #echo ${secrets[USERNAME]}; echo ${secrets[PASSWORD]}; echo ${secrets[IP]}; echo ${secrets[PORT]}

    GRAFANA_IP_1="${secrets[GRAFANA_IP_1]}"
    GRAFANA_IP_2="${secrets[GRAFANA_IP_2]}"
    GRAFANA_APIKEY_1="${secrets[GRAFANA_APIKEY_1]}"
    GRAFANA_APIKEY_2=${secrets[GRAFANA_APIKEY_2]}

    ### KNOWN HOSTS & API KEYS
    GRAFANAEXPORTKNOWNHOSTS=("${GRAFANA_IP_1}"
                             "${GRAFANA_IP_2}")
    GRAFANAEXPORTKNOWNAPIKEYS=("${GRAFANA_APIKEY_1}"
                               "${GRAFANA_APIKEY_2}")

    ### USER INPUTS
    # Default Target
    GRAFANAEXPORTTARGET=${GRAFANAEXPORTTARGET:="http://192.168.0.222"}
    # Default Port
    GRAFANAEXPORTPORT=${GRAFANAEXPORTPORT:=7000}
    # Default No Zip
    GRAFANAEXPORTNOZIP=${GRAFANAEXPORTNOZIP:=0}
    # Default List Known Hosts
    GRAFANAEXPORTLISTHOSTS=${GRAFANAEXPORTLISTHOSTS:=0}

    # If target not in known list then confirm API provided
    if [[ "${GRAFANAEXPORTKNOWNHOSTS[*]}" != *"$GRAFANAEXPORTTARGET"* ]]; then 
        msg_info "Specified target not in known hosts list"; 
        if [[ -z "$GRAFANAEXPORTAPIKEY" ]]; then msg_error "No API key specified!"; exit 1; fi
    fi

    # If no API key explicitly specified then look in known list
    if [[ -z "$GRAFANAEXPORTAPIKEY" ]]; then
        # Find host in known hosts and get API key if found.
        for i in "${!GRAFANAEXPORTKNOWNHOSTS[@]}"; do
            #GRAFANAEXPORTKNOWNHOST="${GRAFANAEXPORTKNOWNHOSTS[$i]}"
            if [[ "$GRAFANAEXPORTTARGET" == "${GRAFANAEXPORTKNOWNHOSTS[$i]}" ]]; then
                GRAFANAEXPORTAPIKEY="${GRAFANAEXPORTKNOWNAPIKEYS[$i]}"
            fi
        done
    fi

    # Sanity check - do we have all necessary values?
    # SHouldn't ever trigger these errors.
    if [[ -z "$GRAFANAEXPORTTARGET" ]]; then msg_error "No target value found!"; exit 1; fi
    if [[ -z "$GRAFANAEXPORTAPIKEY" ]]; then msg_error "No API value found!"; exit 1; fi
    if [[ -z "$GRAFANAEXPORTPORT" ]]; then msg_error "No port value found!"; exit 1; fi

    # COMMAND SYNTAX
    #   curl -H "Authorization: Bearer <paste key here>" https://play.grafana.com/api/search
    GRAFANAEXPORTHOST="$GRAFANAEXPORTTARGET:$GRAFANAEXPORTPORT"
    GRAFANAEXPORTHEADERAUTH="-H \"Authorization: Bearer $GRAFANAEXPORTAPIKEY\""

    ### COLOURS
    red=$(tput setaf 1)
    green=$(tput setaf 2)
    yellow=$(tput setaf 3)
    blue=$(tput setaf 4)
    #magenta=$(tput setaf 5)
    lime=$(tput setaf 190)
    cyan=$(tput setaf 6)
    under=$(tput sgr 0 1)
    reset=$(tput sgr0)

    ### DIRECTORIES
    # Filenames are defined within each export function.
    SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    DIREXPORT="$SCRIPTDIR/latest-export"
    FILETEMP="/tmp/grafana_export.tmp"

    # Dashboards
    DIRDASHBOARDS="$DIREXPORT/dashboards"
    # Datasources
    DIRDATASOURCES="$DIREXPORT/datasources"
    # Alerters
    DIRALERT="$DIREXPORT/alert-notifications"
    # Settings
    DIRSETTINGS="$DIREXPORT/settings"
    FILESETTINGS="$DIRSETTINGS/settings.txt"

    # Zipped Export
    DIRARCHIVE=$SCRIPTDIR/zipped-exports
    DATETIME=$(date '+%Y%m%d-%H%M%S')
    #IP="$( echo "$GRAFANAEXPORTTARGET" | sed -r 's|^https?://||' )"
    #IPUNDERSCORES="${IP//./_}"
    IPUNDERSCORES="$( echo "$GRAFANAEXPORTTARGET" | sed -r 's|^https?://||' | sed 's|\.|_|g' )"
    FILEARCHIVE=$DIRARCHIVE/$DATETIME-$IPUNDERSCORES.zip
}

##### USAGE / HELP ################################################################################
function usage () {
    
    # Process variables - to get defaults for help message.
    initial-vars "$@"

    # Get script path and compare to current path to make example commands
    # look nicer and have full path to script if not currently in same dir.
    WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    if [ "$WHEREAMI" == "$PWD" ]; then SCRIPTPATH="."; else SCRIPTPATH="$WHEREAMI"; fi

    echo
    echo "${cyan}==============================================================================================================================================="
    echo "${green}                                               EXTRACT GRAFANA CONFIGURATION${cyan}"
    echo "-----------------------------------------------------------------------------------------------------------------------------------------------"
    echo "Tool will extract the current set of Grafana dashboards, datasources, alerters, and settings information."
    echo "The target Grafana instance needs to have it's main GUI accessible via it's FQDN or IP address - the same address is used for API access. A"
    echo "'Service Account' API key must also be created in order ot access the data."
    echo "Target IP addresses (or FQDNs) and API keys can be saved in this script's \$GRAFANAEXPORTKNOWNHOSTS & \$GRAFANAEXPORTKNOWNAPIKEYS arrays to"
    echo "allow easy use of this script by passing only a target address. Otherwise the target address and API key must be supplied (see below)."
    echo
    echo "The uncompressed extract will be saved in:"
    echo "    ${blue}$DIREXPORT${cyan}"
    echo "The extract will also be compressed and saved in a timestamped zip file at:"
    echo "    ${blue}$DIRARCHIVE${cyan}"
    echo "The creation of a zipped archive can be skipped by using the ${yellow}--no-zip${cyan} argument."
    echo
    echo "Target Grafana address (including protocol) from which to extract data can be specified with the argument ${red}--target${cyan}. The script will attempt to"
    echo "match the supplied target address to a set of known Grafana hosts saved in script array ${red}\$KNOWNHOSTS${cyan}. If found in the array, the corresponding"
    echo "API key from array ${blue}\$KNOWNAPIKEYS${cyan} will be used for authentication."
    echo "If the target Grafana instance is not in the script's list of known hosts then an API key must also be supplied (${blue}--apikey${cyan})."
    echo
    echo "A port must be specified if different from the default (${green}$GRAFANAEXPORTPORT${cyan})."
    echo
    echo "Script defaults can be permanently changed by updating variables inside script."
    echo
    echo "${under}SYNTAX${reset}"
    echo "${reset}$SCRIPTPATH/$(basename "$0") ${red}[--target <http(s)://IP-ADDRESS>] ${blue}[--apikey <API-KEY>] ${green}[--port <PORT>] ${yellow}--no-zip${cyan}"
    echo "${reset}$SCRIPTPATH/$(basename "$0") ${lime}--known-hosts-list${cyan}"
    echo
    echo "${under}PARAMETER                             VALUE                   DESCRIPTION                                                                      ${reset}"
    echo "${red}-t --target <http(s)://IP-or-FQDB>    $GRAFANAEXPORTTARGET    ${cyan}Specify target protocol & IP/FQDN where Grafana of Grafana instance."
    echo "${blue}-a --apikey <API-KEY>                 $GRAFANAEXPORTAPIKEY"
    echo "                                                              ${cyan}If target is not known by script then supply 'Service Account' API key."
    echo "${green}-p --port <PORT>                      $GRAFANAEXPORTPORT                    ${cyan}Specify target port if different from default."
    echo "${yellow}-n --no-zip                           $GRAFANAEXPORTNOZIP                       ${cyan}Use this flag if no extract archive is required."
    echo "${lime}--known-hosts-list                    $GRAFANAEXPORTLISTHOSTS                       ${cyan}List details of hosts known by script. No other actions will be performed."
    echo
    echo "${under}EXAMPLES${reset}"
    echo "${cyan}List hosts known by the script:${reset}"
    echo "    $SCRIPTPATH/$(basename "$0") --known-hosts-list"
    echo "${cyan}Extract data from default Grafana instance (zipped archive of extract created by default):${reset}"
    echo "    $SCRIPTPATH/$(basename "$0")"
    echo "${cyan}Extract data from default Grafana instance - do not create a zipped archive of extracted data:${reset}"
    echo "    $SCRIPTPATH/$(basename "$0") --no-zip"
    echo "${cyan}Extract data from specified Grafana instance - target in script's list of known hosts:${reset}"
    echo "    $SCRIPTPATH/$(basename "$0") --target 'http://192.168.0.123'"
    echo "${cyan}Extract data from specified Grafana instance - target NOT in script's list of known hosts:${reset}"
    echo "    $SCRIPTPATH/$(basename "$0") --target 'http://192.168.0.124' --apikey 'glsa_1234567890' --port 7001"
    echo
    echo "${under}NOTES${reset}"
    echo "${cyan}• Grafana API access can be tested by running an API command e.g. to list all dashboards...${blue}"
    echo "    curl -H 'Authorization: Bearer APIKEY' 'TARGET:PORT/api/search?query=' | jq"
    echo "    curl -H 'Authorization: Bearer $GRAFANAEXPORTAPIKEY' '$GRAFANAEXPORTTARGET:$GRAFANAEXPORTPORT/api/search?query=' | jq"
    echo "${cyan}• The zipped archive file lists can be viewed without extracting with...${blue}"
    echo "    unzip -l file.zip"
    echo "${cyan}• Individual files can be extracted from the zipped archive with...${blue}"
    echo "    unzip -j file.zip dir/in/archive/file.txt -d /path/to/unzip/to"
    echo
    echo "${under}TODO${reset}"
    echo "${red}• Check back in future to see if Grafana have updated their API. As of Oct 2023 the Alerts API was updated to enabled export of data in the"
    echo "${red}  'Provisioning' format which allows automatic re-creation in a new Grafana instance by simply placing the exported files in a mounted volume"
    echo "${red}  when starting the container. Hopefully the other APIs will be updated to enable the same functionality."
    echo "${red}• And check if Settings can now be exported with API key, not basic auth only"
    echo "${cyan}===============================================================================================================================================${reset}"
    echo
    exit 0
}


##### PARSE COMMAND LINE INPUT ####################################################################
function parse-input (){

    # Error if less than 2 args (at least 2 args required for this script - title and message)
    #if [[ $# -gt 5 ]]; then
    #    msg_error "Too many input args provided!"
    #    msg_info "For details of how to use, run: ./$(basename "$0") --help"
    #    echo; exit 1
    #fi
    
    # Output args to screen for info
    #if [ $# -gt 0 ]; then echo "Parsing input from user:"; echo "\`$*\`"; echo; fi

    # For getopt details, see Obsidian notes and/or: https://stackoverflow.com/a/29754866
    # Test whether enhanced getopt is available (i.e. `getopt --test` has exit code `4`)
    getopt --test || [ "${PIPESTATUS[0]}" -ne 4 ] && msg_error "Enhanced getopt not available!" && exit 1

    # DEFINE COMMAND LINE OPTIONS
    # Options with REQUIRED input = follow with `:`
    # Options with OPTIONAL input = follow with `::`
    LONGOPTS=help,debug,target:,apikey:,port:,no-zip,known-hosts-list
    OPTIONS=hdt:a:p:n

    # CALL GETOPT TO PARSE OUT INPUT
    PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    [ "${PIPESTATUS[0]}" -ne 0 ] && exit 2 # Check for invalid options
    
    # Reorder command line args to have the `option` args first
    eval set -- "$PARSED"
    
    # Define args since using `nounset`
    #e.g. TOTPACCOUNT='' TOTPALGORITHM='' VCMOUNTONLY=0
    GRAFANAEXPORTNONOPTS=() GRAFANAEXPORTDEBUGGING='' GRAFANAEXPORTTARGET='' GRAFANAEXPORTAPIKEY='' GRAFANAEXPORTPORT='' GRAFANAEXPORTNOZIP='' GRAFANAEXPORTLISTHOSTS=''

    # Process arguments in order and split until we see `--`
    while true; do
        case "$1" in
            # DEBUG?
            -d|--debug)
                GRAFANAEXPORTDEBUGGING=1
                shift
                ;;
            # TARGET
            -t|--target)
                GRAFANAEXPORTTARGET="$2"
                shift 2
                ;;
            # API
            -a|--apikey)
                GRAFANAEXPORTAPIKEY="$2"
                shift 2
                ;;
            # PORT
            -p|--port)
                GRAFANAEXPORTPORT="$2"
                shift 2
                ;;
            # NO ZIP
            -n|--no-zip)
                GRAFANAEXPORTNOZIP=1
                shift
                ;;
            --known-hosts-list)
                GRAFANAEXPORTLISTHOSTS=1
                shift
                ;;
            -h|--help)
                usage "$@"
                ;;
            --)
                shift
                break
                ;;
            *)
                msg_error "Command Line Option Error! Check input!"
                exit 3
                ;;
        esac
    done

    # After shifting above, `$@` now matches only our non-option args.
    # Assign to array for later use outside function if needed.
    if [[ $# -ne 0 ]]; then 
        GRAFANAEXPORTNONOPTS=("$@")
        if [[ $GRAFANAEXPORTDEBUGGING -eq 1 ]]; then
            msg_info "Args remaining after parsing defined 'options': ${GRAFANAEXPORTNONOPTS[*]}"
        fi
    fi

    # Check we have expected number of non-option arguments - zero for this script!
    if [[ $# -ne 0 ]]; then 
        msg_error "All command line inputs must be preceded by a valid 'option': ${GRAFANAEXPORTNONOPTS[*]}"
        msg_error "View usage with: ./$(basename "$0") --help"
        exit 4 #Exit status: Interrupted system call
    fi

}


##### CREATE EXPORT DIRS ###############################################################################

create-exportdirs() {
    ### CREATE EXPORT DIRS
    # Otherwise error after deleting previous export
    mkdir -p "$DIREXPORT"
    mkdir -p "$DIRDASHBOARDS"
    mkdir -p "$DIRDATASOURCES"
    mkdir -p "$DIRALERT"
    mkdir -p "$DIRSETTINGS"
    mkdir -p "$DIRARCHIVE"

    # Add file to clarify source host
    touch "$DIREXPORT/$IPUNDERSCORES"
}

##### DEBUGGING EXIT TRAP ###################################################################################
function exittrap () {
    # If var not set i.e. exit before var set
    GRAFANAEXPORTDEBUGGING=${GRAFANAEXPORTDEBUGGING:=0}  
    # Debuging - print varibles
    if [[ $GRAFANAEXPORTDEBUGGING = 1 ]]; then
        set +o nounset #On error exit, likely to not have defined some of the vars below yet.
        echo
        echo "==== DEBUGGING OUTPUT ==========================================="
        # Prints all variables but we only want the ones starting with 'NOTIFY'
        (set -o posix; set) | grep "GRAFANAEXPORT"
        echo "================================================================="
        echo 
    fi
}

# Trap on ALL exits
trap exittrap EXIT 

##### ERROR HANDLER ###############################################################################

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

function error_handler() {
    local exit_code="$?"
    local line_number="$1"
    local command="$2"
    # shellcheck disable=SC2028
    local RESET=$(echo "\033[m"); 
    # shellcheck disable=SC2028
    local RED=$(echo "\033[01;31m"); 
    # shellcheck disable=SC2028
    local YELLOW=$(echo "\033[33m")  
    local error_message="${RESET}[$(date +%Y%m%d-%H%M%S)] ${RED}ERROR:${RESET} in line ${RED}$line_number${RESET}: exit code ${RED}$exit_code${RESET}: while executing command ${YELLOW}$command${RESET}"
    echo -e "\n$error_message\n"
    #cleanup_function
    exit
}

##### INDENT #####################################################################################

# Indents echo'ed text if piped to this function
function indent() { sed 's/^/    /'; }

##### MESSAGES ####################################################################################


function msg_info() {
    # shellcheck disable=SC2028,SC2116,SC2155
    local RESET=$(echo "\033[m"); 
    # shellcheck disable=SC2028,SC2116,SC2155
    local YELLOW=$(echo "\033[33m"); 
    # shellcheck disable=SC2028,SC2116,SC2155
    local INFO="${YELLOW}🛈${RESET}"
    local msg="$1"
    echo -e "${RESET}[$(date +%Y%m%d-%H%M%S)] ${INFO} ${YELLOW}${msg}${RESET}"
}

function msg_ok() {
    # shellcheck disable=SC2028,SC2116,SC2155
    local RESET=$(echo "\033[m"); 
    # shellcheck disable=SC2028,SC2116,SC2155
    local GREEN=$(echo "\033[1;92m");
    # shellcheck disable=SC2028,SC2116,SC2155
    local CHECKMARK="${GREEN}✓${RESET}";
    # shellcheck disable=SC2028,SC2116,SC2155
    local CLEARCURRLINE="\\r\\033[K"
    local msg="$1"
    echo -e "${CLEARCURRLINE}${RESET}[$(date +%Y%m%d-%H%M%S)] ${CHECKMARK} ${GREEN}${msg}${RESET}"
}

function msg_error() {
    # shellcheck disable=SC2028,SC2116,SC2155
    local RESET=$(echo "\033[m");
    # shellcheck disable=SC2028,SC2116,SC2155
    local RED=$(echo "\033[01;31m"); 
    # shellcheck disable=SC2028,SC2116,SC2155
    local CROSS="${RED}✗${RESET}"; 
    # shellcheck disable=SC2028,SC2116,SC2155
    local CLEARCURRLINE="\\r\\033[K"
  local msg="$1"
  echo -e "${CLEARCURRLINE}${RESET}[$(date +%Y%m%d-%H%M%S)] ${CROSS} ${RED}${msg}${RESET}"
}



### GET API DATA ##############################################################################################

fetch-api() {
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/${1}" | jq -r "if type==\"array\" then .[] else . end"
}

### EXPORT DASHBOARDS ##############################################################################################

export-dashboards() {

    echo "======================================================================================"; echo; 
    echo "EXPORTING DASHBOARDS ..."; 

    #==== Define target filename
    FILEDASHBOARDS="$DIRDASHBOARDS/dashboards.json"

    #==== Grab dashboard data and save in txt file in dashboard dir
    fetch-api 'search?query=&' | tee "$FILEDASHBOARDS"  >/dev/null

    #==== Parse dashboard data into useable fields:
    #cat "$FILEDASHBOARDS" | jq -r "[.title, .uid, .type, .folderTitle] | @csv" | tee "$FILETEMP" >/dev/null
    jq -r "[.title, .uid, .type, .folderTitle] | @csv" "$FILEDASHBOARDS" | tee "$FILETEMP" >/dev/null

    #==== For each entry:
    #====   - check if it's a folder = create subdir
    #====   - or grab dashboard data and save in correct subdir
    while IFS="," read -r RECTITLE RECUID RECTYPE RECFOLDERTITLE; do
        
        # Remove quotes from string
        RECTITLE=$(echo "$RECTITLE" | tr -d '"')
        RECUID=$(echo "$RECUID" | tr -d '"')
        RECTYPE=$(echo "$RECTYPE" | tr -d '"')
        RECFOLDERTITLE=$(echo "$RECFOLDERTITLE" | tr -d '"')

        echo
        echo -e "Dashboard Title = \t $RECTITLE"
        echo -e "UID = \t\t\t $RECUID"
        echo -e "Type = \t\t\t $RECTYPE"
        echo -e "Folder Title = \t\t $RECFOLDERTITLE"

        # If type = dash-folder, create subdir in dashboard directory
        if [[ $RECTYPE = "dash-folder" ]]; then
            mkdir -p "$DIRDASHBOARDS/$RECTITLE"

        # If type = dash-db, then create subdir which aligns with folder name
        # (we probably already hyave a corresponding folder due to type=dash-folder handling above)
        # If foldertitle doesn't exist the dashboard is in 'general' folder. 
        # Then grab dashboard details.
        elif [[ $RECTYPE = "dash-db" ]]; then

            # Handle dashboards with no foldertitle i.e. in 'general' folder
            if [[ $RECFOLDERTITLE = "" ]]; then RECFOLDERTITLE="general"; fi

            # Create folder
            mkdir -p "$DIRDASHBOARDS/$RECFOLDERTITLE"

            # Grab DB info            
            curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/dashboards/uid/$RECUID" | \
                jq  'del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' | \
                tee "$DIRDASHBOARDS/$RECFOLDERTITLE/$RECTITLE.json"  >/dev/null

        else
            echo "ERROR - DASHBOARD EXTRACTS NOT COMPLETE."
            echo "Dashboard type ($RECTYPE) not recognised. Review dashboard output and update script to handle."
            echo "Make sure you're not using commas in Dashboard names!!!"

            exit 1
        fi

        # NO LONGER DOING BELOW STEP IN THIS SCRIPT - INTEGRATED INTO IMPORT SCRIPT INSTEAD.
            # Strip first 'id' line to enable import without error - Grafana applies an ID on import.

    done < "$FILETEMP"
    rm "$FILETEMP"
}

### EXPORT DATASOURCES ##############################################################################################

export-datasources() {

    echo "======================================================================================"; echo; 
    echo "EXPORTING DATASOURCES ..."

    #==== Define target filename
    FILEDATASOURCES="$DIRDATASOURCES/datasources.json"

    #==== Grab datasource data and save in txt file
    fetch-api 'datasources' | tee "$FILEDATASOURCES"  >/dev/null

    #=== Grab ID from datasource info 
    #cat "$FILEDATASOURCES" | jq -r "[.id, .name] | @csv" | tee "$FILETEMP" >/dev/null
    #<"$FILEDATASOURCES" jq -r "[.id, .name] | @csv" | tee "$FILETEMP" >/dev/null
    jq -r "[.id, .name] | @csv" "$FILEDATASOURCES" | tee "$FILETEMP" >/dev/null

    #==== For each entry:
    #====   - Grab datasource extract
    while IFS="," read -r RECID RECNAME; do

        # Remove quotes from string
        RECID=$(echo "$RECID" | tr -d '"')
        RECNAME=$(echo "$RECNAME" | tr -d '"')

        echo
        echo -e "Datasource Name = \t $RECNAME"
        echo -e "ID = \t\t\t $RECID"

        # Grab datasource info        
        curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/datasources/$RECID" | \
            jq  '' | \
            tee "$DIRDATASOURCES/$RECNAME.json"  >/dev/null

    done < "$FILETEMP"
    rm "$FILETEMP"
}


export-alerters() {    
# https://grafana.com/docs/grafana/latest/developers/http_api/alerting_provisioning/

    echo "======================================================================================"; echo; 
    echo "EXPORTING ALERTERS ..."

    #############################################################################################################################################

    # OLD API VERSION

    ##==== Define target filename(s)
    #FILEALERTNOTIFICATIONS="$DIRALERT/alert-notifications.txt"
    #
    ##==== Grab alerters data and save in txt file
    #fetch-api 'alert-notifications' | tee "$FILEALERTNOTIFICATIONS"  >/dev/null
    #
    ##=== Grab ID from alerters info 
    ##cat "$FILEALERTNOTIFICATIONS" | jq -r "[.id, .name] | @csv" | tee "$FILETEMP" >/dev/null
    #jq -r "[.id, .name] | @csv" "$FILEALERTNOTIFICATIONS" | tee "$FILETEMP" >/dev/null
    #
    ##==== For each entry:
    ##====   - Grab alerters extract
    #while IFS="," read -r RECID RECNAME; do
    #
    #    # Remove quotes from string
    #    RECID=$(echo "$RECID" | tr -d '"')
    #    RECNAME=$(echo "$RECNAME" | tr -d '"')
    #
    #    echo
    #    echo -e "Alerter Name = \t $RECNAME"
    #    echo -e "ID = \t\t\t $RECID"
    #
    #    # Grab alerter info        
    #    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/alert-notifications/$RECID" | \
    #        jq  'del(.created,.updated)' | \
    #        tee "$DIRALERT/$RECNAME.json"  >/dev/null
    #done < "$FILETEMP"
    #rm "$FILETEMP"

    #############################################################################################################################################

    #fetch-api() {
    #    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/${1}" | jq -r "if type==\"array\" then .[] else . end"
    #}

    #=== Files - MOVE DEFINITIONS TO TOP
    FILE_ALERT_RULES_PREFIX="$DIRALERT/alert-rules"
    FILE_CONTACT_POINTS_PREFIX="$DIRALERT/contact-points"
    FILE_NOTIFICATION_POLICIES_PREFIX="$DIRALERT/notification-policies"
    FILE_TEMPLATES_PREFIX="$DIRALERT/templates"

    # https://grafana.com/docs/grafana/latest/developers/http_api/alerting_provisioning/

    #=== ALERT RULES
    # /api/v1/provisioning/alert-rules                  #=== Alert rules - json - all
    # /api/v1/provisioning/alert-rules/export           #=== Alert rules - yaml provisioning format - all
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/alert-rules" | tee "$FILE_ALERT_RULES_PREFIX-ALL.json"  >/dev/null
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/alert-rules/export" | tee "$FILE_ALERT_RULES_PREFIX-provisioning-ALL.yaml"  >/dev/null
    
    # /api/v1/provisioning/alert-rules/{UID}            #=== Alert rules - json - individual
    # /api/v1/provisioning/alert-rules/{UID}/export     #=== Alert rules - yaml provisioning format - individual
    while IFS="," read -r RECID RECTITLE; do 
        RECID=$(echo "$RECID" | tr -d '"')
        RECTITLE=$(echo "$RECTITLE" | tr -d '"' | sed 's| |_|g' | sed 's|[\,\.\<\>\%\$\#\*\°]||g')
        curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/alert-rules/$RECID" | tee "$FILE_ALERT_RULES_PREFIX-$RECTITLE.json"  >/dev/null
        curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/alert-rules/$RECID/export" | tee "$FILE_ALERT_RULES_PREFIX-provisioning-$RECTITLE.yaml"  >/dev/null
    done <<<$(cat "$FILE_ALERT_RULES_PREFIX-ALL.json" | jq -r "if type==\"array\" then .[] else . end" | jq -r "[.uid, .title] | @csv")

    #=== CONTACT POINTS 
    # /api/v1/provisioning/contact-points               #=== Contact Points - json - all
    # /api/v1/provisioning/contact-points/export        #=== Contact Points - yaml provisioning format - all
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/contact-points" | tee "$FILE_CONTACT_POINTS_PREFIX.json"  >/dev/null
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/contact-points/export" | tee "$FILE_CONTACT_POINTS_PREFIX-provisioning.yaml"  >/dev/null
    
    #=== NOTIFICATION POLICIES
    # /api/v1/provisioning/policies                     #=== Notification policy tree
    # /api/v1/provisioning/policies/export              #=== Notification policy tree - yaml provisioning format
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/policies" | tee "$FILE_NOTIFICATION_POLICIES_PREFIX.json"  >/dev/null
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/policies/export" | tee "$FILE_NOTIFICATION_POLICIES_PREFIX-provisioning.yaml"  >/dev/null

    #=== TEMPLATES
    # /api/v1/provisioning/templates                    #=== Notification templates - all
    # /api/v1/provisioning/templates/{name}             #=== Notification templates - individual
    curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/templates" | tee "$FILE_TEMPLATES_PREFIX-ALL.json"  >/dev/null
    while IFS="," read -r RECNAME; do 
        RECNAME=$(echo "$RECNAME" | tr -d '"')
        RECNAME_CLEAN=$(echo "$RECNAME" | tr -d '"' | sed 's| |_|g' | sed 's|[\,\.\<\>\%\$\#\*\°]||g')
        curl -sSL -f -k "$GRAFANAEXPORTHEADERAUTH" "${GRAFANAEXPORTHOST}/api/v1/provisioning/templates/$RECNAME" | tee "$FILE_TEMPLATES_PREFIX-$RECNAME_CLEAN.json"  >/dev/null
    done <<<$(cat "$FILE_TEMPLATES_PREFIX-ALL.json" | jq -r "if type==\"array\" then .[] else . end" | jq -r "[.name] | @csv")

}


### EXPORT SETTINGS ########################################################################################

export-settings() {
# https://grafana.com/docs/grafana/latest/developers/http_api/admin/

    echo "======================================================================================"; echo; 
    echo "EXPORTING SETTINGS ..."

    echo "ONLY WORKS WITH BASIC AUTH - SKIPPING!!!"

        #==== Grab settings data and save in txt file
        # ONLY WORKS WITH BASIC AUTHENTICATION !!!
        #fetch-api 'admin/settings' | tee "$FILESETTINGS"  #>/dev/null
        #CMDRESULT="$?"
        #if [[ $CMDRESULT -ne 0 ]] || [[ $(cat "$FILESETTINGS") == "" ]]; then
        #    echo "Settings export failed" | tee "$FILESETTINGS" 
        #fi
    
    echo
}

### ZIP EXPORT ########################################################################################

zip-export(){

    echo "======================================================================================"; echo; 
    echo "EXPORTING DASHBOARDS ..."; 

    # Zip extract for archiving
    echo "Creating zip archive ..."
    cd "$DIREXPORT"||exit 1
    zip -r "$FILEARCHIVE" ./*
}


### LIST KNOWN HOSTS ##############################################################################################

list-known-hosts() {

    # Write header
    msg_info "LISTING KNOWN HOSTS"
    printf "%40s\t%-50s\n" "Host" "API Key"
    
    # Iterate through array indexes
    for i in "${!GRAFANAEXPORTKNOWNHOSTS[@]}"; do
        printf "%40s\t%-50s\n" "${GRAFANAEXPORTKNOWNHOSTS[$i]}" "${GRAFANAEXPORTKNOWNAPIKEYS[$i]}"
    done

    echo

    msg_info "VALUES SELECTED"
    msg_info "i.e. values after parsing command line parameters (useful for debugging)"
    printf "%40s\t%-50s\n" "Target" "$GRAFANAEXPORTTARGET"
    printf "%40s\t%-50s\n" "API Key" "$GRAFANAEXPORTAPIKEY"
    printf "%40s\t%-50s\n" "Port" "$GRAFANAEXPORTPORT"
    printf "%40s\t%-80s\n" "Target Curl Command?" "curl $GRAFANAEXPORTHEADERAUTH ${GRAFANAEXPORTHOST}/api/..."
    printf "%40s\t%-50s\n" "Do Not Create Zip?" "$GRAFANAEXPORTNOZIP"

    echo

}



### MAIN FUNCTION ##############################################################################################

main (){  
# INPUT ARGS
# ARG                    SCRIPT VARIABLE    
#--target <IP Address>   GRAFANAEXPORTTARGET
#--apikey <API Key>      GRAFANAEXPORTAPIKEY
#--port <Port>           GRAFANAEXPORTPORT
#--no-zip                GRAFANAEXPORTNOZIP
#--known-hosts-list      GRAFANAEXPORTLISTHOSTS

    # Parse command line inputs
    parse-input "$@"

    # Prep variables
    initial-vars "$@"

    # List known hosts
    if [[ $GRAFANAEXPORTLISTHOSTS -eq 1 ]]; then list-known-hosts "$@"; exit; fi

    # Delete existing extracts
    rm -rf "${DIREXPORT:?}/"*
    
    create-exportdirs
    export-dashboards
    export-datasources
    export-alerters
    export-settings

    # Zip Extract
    if [[ $GRAFANAEXPORTNOZIP -eq 0 ]]; then zip-export; fi

    # TEMP FUNCTION TO FIX OLD ZIP FILENAMES
    #rename-zips

}

### RUN SCRIPT #################################################################################################

echo
main "$@"
echo









# IF WE NEED TO USE A TEMP FUNCTION LIKE THIS THEN IT NEEDS TO COME ABOVE THE 'RUN SCRIPT' SECTION!!!!!
# MOVED HERE TO RETAIN A RECORD BUT STILL GET IT OUT OF THE WAY
#### TEMPORARY - RENAMEOLD ZIPS ##############################################################################################
## Old zip files did not contain the Grafana IP address. Need to add old IP to previous archive filenames.
#
#rename-zips() {
#
#    for file in "$DIRARCHIVE/"*".zip"; do
#        # If filename doesn't already conatin IP
#        if [[ "$file" != *"192_168"* ]]; then
#            IP="192_168_0_10"
#            OLDFILENAME="$(basename "$file")"
#            OLDFILENAMEEXT="${OLDFILENAME##*.}"
#            OLDFILENAMENOEXT="${OLDFILENAME%.*}"
#            NEWFILENAME="$OLDFILENAMENOEXT-$IP.$OLDFILENAMEEXT"
#
#            echo "Renaming: $DIRARCHIVE/$OLDFILENAME"
#            echo "To:       $DIRARCHIVE/$NEWFILENAME"
#            mv "$DIRARCHIVE/$OLDFILENAME" "$DIRARCHIVE/$NEWFILENAME"
#            echo
#        fi
#    done
#
#}