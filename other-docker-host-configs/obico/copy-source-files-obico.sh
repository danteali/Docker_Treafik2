#!/bin/bash

# Check running as root - attempt to restart with sudo if not already running with root
if [ "$(id -u)" -ne 0 ]; then echo "$(tput setaf 1)Not running as root, attempting to automatically restart script with root access...$(tput sgr0)"; echo; sudo "$0" "$@"; exit 1; fi

# Force change directory to the script's folder
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#===================================================================================================
# SET SCRIPT VARIABLES
#===================================================================================================

REMOTE_HOST="obico"    # Must be defined in /etc/ssh/ssh_config with SSH key and user

# Enable/disable sections of the script
COPY_CRONTABS=true
COPY_DOCKER_SCRIPTS=true
COPY_DOCKER_APPDATA=true

# COPY CRONATBS
CRONTABS_LOCAL="crontabs"      # Local directory to save copied files w.r.t. this script's location

# DOCKER SCRIPTS
DOCKER_SCRIPTS_LOCAL="scripts-docker"   # Local directory to save copied files w.r.t. this script's location
DOCKER_SCRIPTS_REMOTE="scripts/docker"   # Source file path on remote host with respect to SSH user's home directory
# EXCLUSIONS
# • By default we copy all in the docker scripts folder but may need to exclude some (e.g.large logs)
# • Exclusion paths are with respect to the source directory (e.g. '${HOME}/scripts/docker/')
# • The rsync --archive flag copies symlinks as symlinks and does not follow them so no need to
#   exclude symlinks in source. e.g. victorismetrics/data/data -> /mnt/datastore/victoriametrics
DOCKER_SCRIPTS_EXCLUDE=(
    # Ansible backup filename syntax 
    "*~"
)

# DOCKER APPDATA
DOCKER_APPDATA_LOCAL="storage-docker"      # Local directory to save copied files w.r.t. this script's location
DOCKER_APPDATA_REMOTE="/storage/Docker/"  # Source file path on remote host - absolute path
# EXCLUSIONS
# • By default we copy all in the docker storage folder but may need to exclude some (e.g.large logs)
# • Exclusion paths are with respect to the source directory (e.g. '/storage/Docker/')
# • The rsync --archive flag copies symlinks as symlinks and does not follow them so no need to
#   exclude symlinks in source. e.g. victorismetrics/data/data -> /mnt/datastore/victoriametrics
# • Exclude common temporary or cache files

DOCKER_APPDATA_EXCLUDE=(
    # Ansible backup filename syntax 
    "*~"
    # Application specific excludes - monitoring
    "chronograf"
    "grafana/data/data"
    "nodeexporter"
    "octograph/data/_archive"
    "octograph/data/logs"
    # Application specific excludes - frigate
    "frigate/data/data"
    "frigate/data/config/model_cache"
    "frigate/data/config/.*"
)


#===================================================================================================
# RUN SCRIPT
#===================================================================================================
function main() {
    parse-input "$@"
    display-settings
    prerequisites

    if [ "$COPY_CRONTABS" = true ]; then
        copy-crontabs
    fi
    if [ "$COPY_DOCKER_SCRIPTS" = true ]; then
        copy-docker-scripts
    fi
    if [ "$COPY_DOCKER_APPDATA" = true ]; then
        copy-docker-appdata
    fi
}

#===================================================================================================
# PARSE COMMAND LINE ARGUMENTS
#===================================================================================================
function parse-input() {
    # If any arguments are provided then override the default settings above
    if [ "$#" -gt 0 ]; then
        for arg in "$@"; do
            case $arg in
                --no-crontabs) COPY_CRONTABS=false ;;
                --no-scripts) COPY_DOCKER_SCRIPTS=false ;;
                --no-appdata) COPY_DOCKER_APPDATA=false ;;
                --crontabs-only) 
                    COPY_CRONTABS=true
                    COPY_DOCKER_SCRIPTS=false
                    COPY_DOCKER_APPDATA=false
                    ;;
                --scripts-only)
                    COPY_CRONTABS=false
                    COPY_DOCKER_SCRIPTS=true
                    COPY_DOCKER_APPDATA=false
                    ;;
                --appdata-only)
                    COPY_CRONTABS=false
                    COPY_DOCKER_SCRIPTS=false
                    COPY_DOCKER_APPDATA=true
                    ;;
                --verbose) RSYNC_VERBOSE=true ;;
                --remote-host=*) 
                    REMOTE_HOST="${arg#*=}"
                    # If a REMOTE_HOST sub-directory exists in this script's folder then use that for local storage
                    if [ -d "${WHEREAMI}/${REMOTE_HOST}" ]; then
                        WHEREAMI=${WHEREAMI}/${REMOTE_HOST}
                    else
                        echo; msg_error "No sub-directory for user specified remote host '${REMOTE_HOST}' found in script directory. Exiting!"
                        echo
                        exit 1
                    fi
                    ;;
                --help|-h) 
                    echo; echo "Usage: sudo $0 [options]"
                    echo
                    echo "Description:"
                    echo "  Copies crontabs, docker scripts and docker application data from remote host"
                    echo "  '${REMOTE_HOST}' to local directories within this script's folder."
                    echo "  Define REMOTE_HOST and source/target directories in the script variables section."
                    echo "  By default all three sections are run, use options below to skip sections."
                    echo "  The remote host must be defined in /etc/ssh/ssh_config with SSH key and user."
                    echo
                    echo "  The REMOTE_HOST can also be specified on the command line, if specified then the"
                    echo "  script will also look for a REMOTE_HOST sub-directory in it's own directory to"
                    echo "  store the copied files. e.g. if REMOTE_HOST='otherhost' then the script will copy"
                    echo "  files to:"
                    echo "     '${WHEREAMI}/otherhost/...'."
                    echo "  All exclusions will be the same as defined in the script variables section."
                    echo "  This allows the same script to be used to copy files from multiple remote hosts."
                    echo 
                    echo "Options:"
                    echo "  --no-crontabs     Skip copying crontabs from remote host"
                    echo "  --no-scripts      Skip copying docker scripts from remote host"
                    echo "  --no-appdata      Skip copying docker application data from remote host"
                    echo "  --crontabs-only   Copy only crontabs from remote host (same as --no-scripts --no-appdata)"
                    echo "  --scripts-only    Copy only docker scripts from remote host (same as --no-crontabs --no-appdata)"
                    echo "  --appdata-only    Copy only docker application data from remote host (same as --no-crontabs --no-scripts)"
                    echo "  --verbose         Show detailed output from rsync commands"
                    echo "  --remote-host=    Specify a different remote host defined in /etc/ssh/ssh_config"
                    echo "  --help, -h        Show this help message and exit"
                    echo
                    echo "Examples:"
                    echo "  sudo $0 --no-appdata"
                    echo "  sudo $0 --scripts-only --verbose"
                    echo "  sudo $0 --remote-host=otherhost --no-crontabs"
                    echo
                    exit 0
                    ;;
                *) 
                    echo; echo "Unknown option: $arg"
                    echo "Use --help or -h to see usage information."
                    echo
                    exit 1
                    ;;
            esac
        done
    fi

    # Check if at least one section is enabled, if not then exit with error
    if [ "$COPY_CRONTABS" = false ] && [ "$COPY_DOCKER_SCRIPTS" = false ] && [ "$COPY_DOCKER_APPDATA" = false ]; then
        echo; echo "Error: No sections enabled to run, nothing to do!"
        echo "Use --help or -h to see usage information."
        echo
        exit 1
    fi
}

#===================================================================================================
# DISPLAY SETTINGS
#===================================================================================================
function display-settings() {
    echo "===================================================================================";
    msg_info "SCRIPT SETTINGS"
    echo "  Remote host:                ${REMOTE_HOST}"
    echo
    echo "  Copy crontabs:              ${COPY_CRONTABS}"
    echo "      Local crontabs dir:     ${CRONTABS_LOCAL}"
    echo
    echo "  Copy docker scripts:        ${COPY_DOCKER_SCRIPTS}"
    echo "      Local docker scripts:   ${DOCKER_SCRIPTS_LOCAL}"
    echo "      Remote docker scripts:  ~/${DOCKER_SCRIPTS_REMOTE}"
    echo "      Docker scripts exclude: ${DOCKER_SCRIPTS_EXCLUDE[*]}"
    echo
    echo "  Copy docker appdata:        ${COPY_DOCKER_APPDATA}"
    echo "      Local docker appdata:   ${DOCKER_APPDATA_LOCAL}"
    echo "      Remote docker appdata:  ${DOCKER_APPDATA_REMOTE}"
    echo "      Docker appdata exclude: ${DOCKER_APPDATA_EXCLUDE[*]}"
}

#===================================================================================================
# CHECK PREREQUISITES
#===================================================================================================
function prerequisites() {

    # Current non-sudo user
    ORIGINAL_USER="${SUDO_USER:-$(whoami)}"

    # Define full paths to defined variables - needs to be here in case the user specifies a different
    # REMOTE_HOST on the command line and the script changes WHEREAMI to a sub-directory.
    CRONTABS_LOCAL="${WHEREAMI}/crontabs"         # Local directory to save copied files - ${WHEREAMI} is the directory where this script is located
    DOCKER_SCRIPTS_LOCAL="${WHEREAMI}/scripts-docker"   # Local directory to save copied files - ${WHEREAMI} is the directory where this script is located
    DOCKER_APPDATA_LOCAL="${WHEREAMI}/storage-docker"      # Local directory to save copied files - ${WHEREAMI} is the directory where this script is located


    # Check if REMOTE_HOST is defined in /etc/ssh/ssh_config
    if ! ssh -G "${REMOTE_HOST}" > /dev/null 2>&1; then
        msg_error "Error: Remote host '${REMOTE_HOST}' not defined in /etc/ssh/ssh_config - cannot continue!"
        echo
        exit 1
    fi

    # Check if ssh to REMOTE_HOST works
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" echo "SSH connection to ${REMOTE_HOST} OK" > /dev/null 2>&1; then
        msg_error "Error: Unable to connect to remote host '${REMOTE_HOST}' via SSH - cannot continue!"
        echo
        exit 1
    fi

    # If COPY_CRONTABS or COPY_DOCKER_SCRIPTS is true then get REMOTE_USER from ssh config file
    if [ "$COPY_CRONTABS" = true ] || [ "$COPY_DOCKER_SCRIPTS" = true ]; then
        # Get remote user name from ssh_config file
        REMOTE_USER=$(ssh -G "${REMOTE_HOST}" | awk '/^user / {print $2}')
        # Fallback if no specific user is defined then exit with error
        if [ -z "$REMOTE_USER" ]; then
            msg_error "No user defined for host ${REMOTE_HOST} in /etc/ssh/ssh_config - cannot continue!"
            exit 1
        fi
    fi

    # If COPY_DOCKER_SCRIPTS or COPY_DOCKER_APPDATA is true then check if rsync works on remote host
    if [ "$COPY_DOCKER_SCRIPTS" = true ] || [ "$COPY_DOCKER_APPDATA" = true ]; then
        # Check if rsync is installed on local and remote host
        if ! command -v rsync > /dev/null 2>&1; then
            msg_error "Error: rsync not installed on local host - cannot continue!"
            echo
            exit 1
        fi
        if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" command -v rsync > /dev/null 2>&1; then
            msg_error "Error: rsync not installed on remote host '${REMOTE_HOST}' - cannot continue!"
            echo
            exit 1
        fi
        # Check if sudo rsync works on remote host
        if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" sudo rsync --version > /dev/null 2>&1; then
            msg_error "Error: Unable to run 'sudo rsync' on remote host '${REMOTE_HOST}' - cannot continue!"
            echo
            exit 1
        fi
    fi

    # COMMON RSYNC EXCLUDES
    # Generic exclusions to apply to all rsync commands
    RSYNC_COMMON_EXCLUDE=(
        # Common cache/temp files
        "cache"
        "tmp"
        "temp"
        "tempfiles"
        "logs"
        "log"
        "*.tmp"
        "*.temp"
        "*.log"
        # Backup / archive files
        "*.bak"
        "*.backup"
        "*.old"
        "*.archive"
        "backup"
        "backups"
        "archive"
        "_archive"
        # Exclude datestamped backup files
        "*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].*"
        "*.*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
        "*.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
        # Version control directories
        ".git"
        ".github"
        # System files
        ".DS_Store"
        "Thumbs.db"
        "desktop.ini"
        # Editor/IDE files
        ".vscode"
        ".idea"
        "*.swp"
        "*.swo"
        # Python cache files
        "__pycache__"
        "*.pyc"
        # Node modules
        "node_modules"
        # Go modules
        "vendor"
        # Java files
        "*.class"
        # Ruby files
        "*.gem"
        "vendor"
        # PHP files
        "vendor"
        # Other common excludes
        "downloads"
        "upload"
        "uploads"
    )
} 

#===================================================================================================
# UTILITY FUNCTIONS
#===================================================================================================
function msg_info() {
  # shellcheck disable=SC2155,SC2116,SC2028
  local RESET=$(echo "\033[m") && local YELLOW=$(echo "\033[33m") && local INFO="${YELLOW}📝${RESET}"
  local msg="$1"
  echo -e "${RESET}[$(date +%Y%m%d-%H%M%S)] ${INFO} ${YELLOW}${msg}${RESET}"
}
function msg_ok() {
  # shellcheck disable=SC2155,SC2116,SC2028
  local RESET=$(echo "\033[m") && local GREEN=$(echo "\033[1;92m") && local CHECKMARK="${GREEN}✅${RESET}" && local CLEARCURRLINE="\\r\\033[K"
  local msg="$1"
  echo -e "${CLEARCURRLINE}${RESET}[$(date +%Y%m%d-%H%M%S)] ${CHECKMARK} ${GREEN}${msg}${RESET}"
}
function msg_error() {
  # shellcheck disable=SC2155,SC2116,SC2028
  local RESET=$(echo "\033[m") && local RED=$(echo "\033[01;31m") && local CROSS="${RED}❌${RESET}" && local CLEARCURRLINE="\\r\\033[K"
  local msg="$1"
  echo -e "${CLEARCURRLINE}${RESET}[$(date +%Y%m%d-%H%M%S)] ${CROSS} ${RED}${msg}${RESET}"
}
# Misc - Indents echo'ed text if piped to this function
function indent() { sed 's/^/    /'; }
# Indent messages created with msg* functions e.g. msg_ok "Lockfile found: $file" | indent_msg
function indent_msg() { sed "s/\(\[[0-9]\{8\}-[0-9]\{6\}\] \[.*\] \)/\1    /"; }

#===================================================================================================
# CRONTABS
#===================================================================================================
function copy-crontabs() {

    echo "===================================================================================";
    msg_info "Copying crontabs from remote host (${REMOTE_HOST}) ..."
    echo "--------------------------------------------------------------------------------"

    # Make local crontabs directory if it doesn't already exist (set ownership to non-sudo user)
    sudo -u "$ORIGINAL_USER" mkdir -p "${CRONTABS_LOCAL}"

    # Get remote system's crontab(s) depending on user
    # Get remote user's crontab
    msg_info "Getting ${REMOTE_USER} crontab ..."
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" crontab -l > "${CRONTABS_LOCAL}/${REMOTE_USER}.crontab"; then
        msg_ok "Command completed successfully"
    else
        msg_error "Command reported non-0 exit status, review output for details!"
        exit 1
    fi

    if [ "$REMOTE_USER" = "root" ]; then
        msg_info "Remote user is root, no separate 'root' crontab to obtain. Crontab copy complete."
    else 
        msg_info "Remote user is ${REMOTE_USER}, also getting root crontab ..."
        #if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" sudo crontab -l > "${CRONTABS_LOCAL}/root.crontab"; then
        #    msg_ok "Command completed successfully"
        #else
        #    msg_error "Command reported non-0 exit status, review output for details!"
        #    exit 1
        #fi
        # Have to use rsync since can't get root crontabn without SSHing as root user in the first place.
        ROOT_CRONTAB_PATH="/var/spool/cron/crontabs/root"   # For Debian based systems
        #ROOT_CRONTAB_PATH="/var/spool/cron/root"            # For Red Hat/CentOS based systems
        #ROOT_CRONTAB_PATH="/var/cron/tabs/root"             # For FreeBSD based systems
        if rsync --archive --human-readable --timeout=180 --rsync-path="sudo rsync" "${REMOTE_HOST}:${ROOT_CRONTAB_PATH}" "${CRONTABS_LOCAL}/root.crontab"; then
            # Make copied file readable by non-sudo user
            sudo chmod 644 "${CRONTABS_LOCAL}/root.crontab"
            msg_ok "Command completed successfully"
        else
            msg_error "Command reported non-0 exit status, review output for details!"
            exit 1
        fi
    fi
}

#===================================================================================================
# DOCKER SCRIPTS DIRECTORY - ${HOME}/scripts/docker
#===================================================================================================
function copy-docker-scripts() {    
    echo; echo "==================================================================================="; echo
    msg_info "Copying docker scripts from remote host (${REMOTE_HOST}) ..."

    # Get remote user's home directory from username
    if [ "${REMOTE_USER}" = "root" ]; then
    REMOTE_HOME="/root"
    else
    REMOTE_HOME="/home/${REMOTE_USER}"
    fi
    DOCKER_SCRIPTS_SOURCE="${REMOTE_HOME}/${DOCKER_SCRIPTS_REMOTE}"

    msg_info "Remote User: ${REMOTE_USER}"
    msg_info "Source:      ${DOCKER_SCRIPTS_SOURCE}/"
    msg_info "Dest:        ${DOCKER_SCRIPTS_LOCAL}/"
    msg_info "Excluding:   ${DOCKER_SCRIPTS_EXCLUDE[*]}"
    echo "--------------------------------------------------------------------------------"

    # Check if source directory exists on remote host
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" [ -d "${DOCKER_SCRIPTS_SOURCE}" ]; then
        msg_error "Source directory ${DOCKER_SCRIPTS_SOURCE} does not exist on remote host '${REMOTE_HOST}' - cannot continue!"
        exit 1
    fi

    # Prep exclude arguments from user defined array DOCKER_SCRIPTS_EXCLUDE above.
    # Merge RYSNC_COMMON_EXCLUDES and DOCKER_SCRIPTS_EXCLUDE arrays
    DOCKER_SCRIPTS_EXCLUDE=("${DOCKER_SCRIPTS_EXCLUDE[@]}" "${RSYNC_COMMON_EXCLUDE[@]}")
    DOCKER_SCRIPTS_EXCLUDE_ARGS=()
    for EXCLUDE in "${DOCKER_SCRIPTS_EXCLUDE[@]}"; do
        DOCKER_SCRIPTS_EXCLUDE_ARGS+=("--exclude=$EXCLUDE")
    done
    # If no excludes then add a dummy exclude that won't match anything to avoid rsync error
    if [ "${#DOCKER_SCRIPTS_EXCLUDE_ARGS[@]}" -eq 0 ]; then
        DOCKER_SCRIPTS_EXCLUDE_ARGS+=("--exclude=NOEXCLUDESPECIFIED")
    fi    
    
    # Make sure target destination exists (set ownership to non-sudo user)
    sudo -u "$ORIGINAL_USER" mkdir -p "${DOCKER_SCRIPTS_LOCAL}"

    # GENERATE RSYNC COMMAND
    rsync-args
    RSYNCCMD=()
    RSYNCCMD+=("rsync")
    RSYNCCMD+=("${RSYNC_ARGS[@]}")
    RSYNCCMD+=("${DOCKER_SCRIPTS_EXCLUDE_ARGS[@]}")
    RSYNCCMD+=("-e \"ssh ${RSYNC_SSH_OPTIONS[*]}\"")
    RSYNCCMD+=("--rsync-path=\"sudo rsync\"")
    RSYNCCMD+=("${REMOTE_HOST}:${DOCKER_SCRIPTS_SOURCE}/")  # Trailing slash important to copy contents of directory
    RSYNCCMD+=("${DOCKER_SCRIPTS_LOCAL}/")               # Trailing slash not essential but included for consistency

    # EXECUTE RSYNC COMMAND
    msg_info "Rsync command:"
    msg_info "${RSYNCCMD[*]}" | indent_msg
    unset cmdexitcode
    # shellcheck disable=SC2294 # (warning about eval not respecting array separation)
    eval "${RSYNCCMD[@]}"
    # Check if rsync command completed successfully
    cmdexitcode=$?
    if [ ${cmdexitcode} -eq 0 ]; then
        msg_ok "rsync command completed successfully"
    else
        msg_error "rsync command failed - command reported non-0 exit status, review output for details!"
        exit 1
    fi
}

#===================================================================================================
# DOCKER APP DATA - /storage/Docker/
#===================================================================================================
function copy-docker-appdata() {
    echo; echo "==================================================================================="; echo
    msg_info "Copying docker application data from remote host (${REMOTE_HOST}) ..."

    # RSYNC SETTINGS
    DOCKER_APPDATA_SOURCE="${DOCKER_APPDATA_REMOTE}"

    msg_info "Source: ${DOCKER_APPDATA_SOURCE}/"
    msg_info "Dest:   ${DOCKER_APPDATA_LOCAL}/"
    msg_info "Excluding: ${DOCKER_APPDATA_EXCLUDE[*]}"
    echo "--------------------------------------------------------------------------------"

    # Check if source directory exists on remote host
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_HOST}" [ -d "${DOCKER_APPDATA_SOURCE}" ]; then
        msg_error "Source directory ${DOCKER_APPDATA_SOURCE} does not exist on remote host '${REMOTE_HOST}' - cannot continue!"
        exit 1
    fi

    # Prep exclude arguments from user defined array DOCKER_APPDATA_EXCLUDE above.
    # Merge RYSNC_COMMON_EXCLUDES and DOCKER_SCRIPTS_EXCLUDE arrays
    DOCKER_SCRIPTS_EXCLUDE=("${DOCKER_SCRIPTS_EXCLUDE[@]}" "${RSYNC_COMMON_EXCLUDE[@]}")
    DOCKER_APPDATA_EXCLUDE_ARGS=()
    for EXCLUDE in "${DOCKER_APPDATA_EXCLUDE[@]}"; do
        DOCKER_APPDATA_EXCLUDE_ARGS+=("--exclude=$EXCLUDE")
    done
    # If no excludes then add a dummy exclude that won't match anything to avoid rsync error
    if [ "${#DOCKER_APPDATA_EXCLUDE_ARGS[@]}" -eq 0 ]; then
        DOCKER_APPDATA_EXCLUDE_ARGS+=("--exclude=NOEXCLUDESPECIFIED")
    fi    

    # Make sure target destination exists  (set ownership to non-sudo user)
    sudo -u "$ORIGINAL_USER" mkdir -p "${DOCKER_APPDATA_LOCAL}"

    # GENERATE RSYNC COMMAND
    rsync-args
    RSYNCCMD=()
    RSYNCCMD+=("rsync")
    RSYNCCMD+=("${RSYNC_ARGS[@]}")
    RSYNCCMD+=("${DOCKER_APPDATA_EXCLUDE_ARGS[@]}")
    RSYNCCMD+=("-e \"ssh ${RSYNC_SSH_OPTIONS[*]}\"")
    RSYNCCMD+=("--rsync-path=\"sudo rsync\"")
    RSYNCCMD+=("${REMOTE_HOST}:${DOCKER_APPDATA_SOURCE}/")  # Trailing slash important to copy contents of directory
    RSYNCCMD+=("${DOCKER_APPDATA_LOCAL}/")               # Trailing slash not essential but included for consistency

    # EXECUTE RSYNC COMMAND
    msg_info "Rsync command:"
    msg_info "${RSYNCCMD[*]}" | indent_msg
    unset cmdexitcode
    # shellcheck disable=SC2294 # (warning about eval not respecting array separation)
    eval "${RSYNCCMD[@]}"
    # Check if rsync command completed successfully
    cmdexitcode=$?
    if [ ${cmdexitcode} -eq 0 ]; then
        msg_ok "rsync command completed successfully"
    else
        msg_error "rsync command failed - command reported non-0 exit status, review output for details!"
        exit 1
    fi
}

#===================================================================================================
# DEFINE RSYNC ARGS
#===================================================================================================
# Define standard rsync arguments in an array to be used in rsync commands
function rsync-args() {
    # STANDARD RSYNC ARGUMENTS
    RSYNC_SSH_OPTIONS=(
        "-o StrictHostKeyChecking=no"
        "-o UserKnownHostsFile=/dev/null"
    )
    RSYNC_ARGS=(
        "--archive"
        "--compress"
        "--info=progress2"
        "--stats"
        "--human-readable"
        "--itemize-changes"
        "--partial"
        "--acls"
        "--xattrs"
        "--sparse"
        "--timeout=180"
        "--delete"
    )
    # If --verbose option specified on command line then add extra verbosity to rsync args
    if [ "$RSYNC_VERBOSE" = true ]; then
        RSYNC_ARGS+=("--verbose")
        RSYNC_ARGS+=("--progress")
    fi
}

# Run main function
main "$@"


#===================================================================================================
## OLD INDIVIDUAL COPY COMMANDS - kept for reference
#
##/storage/Docker/chronograf - no config files to copy
#
##/storage/Docker/dem
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/dem docker-app-data/
#
##/storage/Docker/grafana
#mkdir -p docker-app-data/grafana/data
#sudo scp -r monitoring:/storage/Docker/grafana/data/provisioning docker-app-data/grafana/data/
#
##/storage/Docker/influxdb
#mkdir -p docker-app-data/influxdb/data
#sudo scp -r monitoring:/storage/Docker/influxdb/data/config docker-app-data/influxdb/data/
#
##/storage/Docker/octograph
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/octograph docker-app-data/
#
##/storage/Docker/snmp-exporter
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/snmp-exporter docker-app-data/
#
##/storage/Docker/varken
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/varken docker-app-data/
#
##/storage/Docker/victoriametrics
#mkdir -p docker-app-data/victoriametrics/data
#sudo scp -r monitoring:/storage/Docker/victoriametrics/data/config docker-app-data/victoriametrics/data/
#
##/storage/Docker/vmagent
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/vmagent docker-app-data/
#
##/storage/Docker/healthchecks
#mkdir -p docker-app-data
#sudo scp -r monitoring:/storage/Docker/healthchecks docker-app-data/
