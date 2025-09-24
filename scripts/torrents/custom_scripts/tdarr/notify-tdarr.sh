#!/bin/bash
# shellcheck disable=
#set -o pipefail -o nounset
echo 


# TODO
# - Add file size and quality to final logging (from input radarr / sonarr env vars)
# - Check arr env vars for codec and only run tdarr if not x265 already
    # sonarr_episodefile_mediainfo_videocodec
    # ??? radarr_moviefile_videocodec


# Original inspiration and code:
# https://github.com/hollanbm/tdarr_autoscan

# COMMANDS FOR TESTING SCRIPT 
# - If testing from docker host - file paths must be the FULL PATH not a relative path. Paths will be dynamically
#   converted to tdarr path mappings.
# - Use sonarr_eventtype/radarr_eventtype = 'test' to skip the final tdarr API call.
# - Possible sonarr_eventtype values:
#       Grab, Download, Rename, EpisodeFileDelete, SeriesDelete, HealthIssue, ApplicationUpdate, Test
# - Possible radarr_eventtype values:
#       Grab, Download, Rename, HealthIssue, ApplicationUpdate, Test
# - Example commands:
#   Test from inside sonarr/radarr/tdarr container - using sonarr/radarr env vars which it will receive if run as sonarr/radarr custom script::
#       sonarr_eventtype=Test sonarr_episodefile_path="/tv/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi" /custom-scripts/tdarr/notify-tdarr.sh
#       sonarr_eventtype=Test sonarr_episodefile_path="/tv/Father.Ted/Season.01/Father.Ted.s01e02.Entertaining.Father.Stone.SDTV.XviD.AC3.2.0.avi" /custom-scripts/tdarr/notify-tdarr.sh
#       sonarr_eventtype=Test sonarr_episodefile_path="/tv/_NOBACKUP/Below.Deck.Mediterranean/Season.09/Below.Deck.Mediterranean.s09e01.My.Big.Fat.Greek.Yacht.Emergency.WEBDL-1080p.mkv" /custom-scripts/tdarr/notify-tdarr.sh
#   Test from sonarr/radarr/tdarr host - using FQDN for path + arr env vars:
#       sonarr_eventtype=Test sonarr_episodefile_path="/storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi" /home/ryan/scripts/docker/scripts/torrents/custom_scripts/tdarr/notify-tdarr.sh
#       sonarr_eventtype=Test sonarr_episodefile_path="/storage/Media/Video/TV/_NOBACKUP/Below.Deck.Mediterranean/Season.09/Below.Deck.Mediterranean.s09e01.My.Big.Fat.Greek.Yacht.Emergency.WEBDL-1080p.mkv" /home/ryan/scripts/docker/scripts/torrents/custom_scripts/tdarr/notify-tdarr.sh
#   Test using cli args to point at target file
#       /home/ryan/scripts/docker/scripts/torrents/custom_scripts/tdarr/notify-tdarr.sh --debug --filepath /storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi


##### RUNNING IN DOCKER? ###############################################################

# Check if running in a docker container or not.
# DO at top of script as we need to know in order to log sonarr / radarr env vars up front.

# RUNNING IN DOCKER?
# Detect and set variable to check if we're running in docker - this allows us to dynamically convert paths used when testing
# or running the script from our host system.
#if grep -q docker /proc/1/cgroup; then
if [ -f /.dockerenv ]; then HOSTSYSTEM="docker"; else HOSTSYSTEM="host"; fi



##### SONARR RADARR ENV VAR LOGGING ###############################################################

# Log sonarr / radarr env vars for help troubleshooting.

function debug_log_all_envars {
    # Log all env vars at time script is triggered - overridden each time
    date +"%Y-%m-%d %H:%M:%S" > "$LOG_LAST_ENVVARS"
    printenv >> "$LOG_LAST_ENVVARS"

    # Log specific sonarr / radarr env vars which are useful to script
    {
    echo
    date +"%Y-%m-%d %H:%M:%S"
    echo "Sonarr Environment Variables"
    echo "Sonarr - sonarr_eventtype: $(printenv sonarr_eventtype)"
    echo "Sonarr - sonarr_isupgrade: $(printenv sonarr_isupgrade)"
    echo "Sonarr - sonarr_series_title: $(printenv sonarr_series_title)"
    echo "Sonarr - sonarr_series_path: $(printenv sonarr_series_path)"
    echo "Sonarr - sonarr_episodefile_path: $(printenv sonarr_episodefile_path)"
    echo "Sonarr - sonarr_episodefile_sourcepath: $(printenv sonarr_episodefile_sourcepath)"
    echo "Sonarr - sonarr_episodefile_sourcefolder: $(printenv sonarr_episodefile_sourcefolder)"
    echo "Sonarr - sonarr_episodefile_quality: $(printenv sonarr_episodefile_quality)"
    echo "Sonarr - sonarr_episodefile_mediainfo_videocodec: $(printenv sonarr_episodefile_mediainfo_videocodec)"
    echo "Sonarr - sonarr_episodefile_mediainfo_audiocodec: $(printenv sonarr_episodefile_mediainfo_audiocodec)"
    echo "Sonarr - sonarr_episodefile_mediainfo_subtitles: $(printenv sonarr_episodefile_mediainfo_subtitles)"
    echo "Sonarr - sonarr_episodefile_seasonnumber: $(printenv sonarr_episodefile_seasonnumber)"
    echo "Sonarr - sonarr_episodefile_episodenumbers: $(printenv sonarr_episodefile_episodenumbers)"
    echo "Sonarr - sonarr_episodefile_episodecount: $(printenv sonarr_episodefile_episodecount)"
    echo "Sonarr - sonarr_release_title: $(printenv sonarr_release_title)"
    echo "Sonarr - sonarr_release_quality: $(printenv sonarr_release_quality)"
    echo "Sonarr - sonarr_release_size: $(printenv sonarr_release_size)"
    echo "Sonarr - sonarr_release_seasonnumber: $(printenv sonarr_release_seasonnumber)"
    echo "Sonarr - sonarr_release_episodenumbers: $(printenv sonarr_release_episodenumbers)"
    echo "Radarr Environment Variables"
    echo "Radarr - radarr_eventtype: $(printenv radarr_eventtype)"
    echo "Radarr - radarr_isupgrade: $(printenv radarr_isupgrade)"
    echo "Radarr - radarr_movie_title: $(printenv radarr_movie_title)"
    echo "Radarr - radarr_movie_path: $(printenv radarr_movie_path)"
    echo "Radarr - radarr_moviefile_path: $(printenv radarr_moviefile_path)"
    echo "Radarr - radarr_moviefile_sourcepath: $(printenv radarr_moviefile_sourcepath)"
    echo "Radarr - radarr_moviefile_sourcefolder: $(printenv radarr_moviefile_sourcefolder)"
    echo "Radarr - radarr_moviefile_quality: $(printenv radarr_moviefile_quality)"
    echo "Radarr - radarr_moviefile_videocodec: $(printenv radarr_moviefile_videocodec)"
    echo "Radarr - radarr_moviefile_audiocodec: $(printenv radarr_moviefile_audiocodec)"
    echo "Radarr - radarr_moviefile_subtitles: $(printenv radarr_moviefile_subtitles)"
    echo "Radarr - radarr_release_title: $(printenv radarr_release_title)"
    echo "Radarr - radarr_release_quality: $(printenv radarr_release_quality)"
    echo "Radarr - radarr_release_size: $(printenv radarr_release_size)"
    echo
    echo "======================================================================"
    } >> "$LOG_ARR_VARS"

    # CSV Fields:
    #   DATETIME 
    #   sonarr_eventtype
    #   sonarr_isupgrade
    #   sonarr_series_title
    #   sonarr_series_path
    #   sonarr_episodefile_path
    #   sonarr_episodefile_sourcepath
    #   sonarr_episodefile_sourcefolder
    #   sonarr_episodefile_quality
    #   sonarr_episodefile_mediainfo_videocodec
    #   sonarr_episodefile_mediainfo_audiocodec
    #   sonarr_episodefile_mediainfo_subtitles
    #   sonarr_episodefile_seasonnumber
    #   sonarr_episodefile_episodenumbers
    #   sonarr_episodefile_episodecount
    #   sonarr_release_title
    #   sonarr_release_quality
    #   sonarr_release_size
    #   sonarr_release_seasonnumber
    #   sonarr_release_episodenumbers
    #   radarr_eventtype
    #   radarr_isupgrade
    #   radarr_movie_title
    #   radarr_movie_path
    #   radarr_moviefile_path
    #   radarr_moviefile_sourcepath
    #   radarr_moviefile_sourcefolder
    #   radarr_moviefile_quality
    #   radarr_moviefile_videocodec
    #   radarr_moviefile_audiocodec
    #   radarr_moviefile_subtitles
    #   radarr_release_title
    #   radarr_release_quality
    #   radarr_release_size
    csv_arr_envvar_pipe="$(date +"%Y-%m-%d %H:%M:%S")"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_eventtype)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_isupgrade)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_series_title)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_series_path)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_path)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_sourcepath)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_sourcefolder)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_quality)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_mediainfo_videocodec)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_mediainfo_audiocodec)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_mediainfo_subtitles)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_seasonnumber)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_episodenumbers)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_episodefile_episodecount)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_release_title)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_release_quality)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_release_size)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_release_seasonnumber)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv sonarr_release_episodenumbers)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_eventtype)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_isupgrade)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_movie_title)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_movie_path)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_path)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_sourcepath)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_sourcefolder)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_quality)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_videocodec)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_audiocodec)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_moviefile_subtitles)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_release_title)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_release_quality)"
    csv_arr_envvar_pipe="${csv_arr_envvar_pipe}|$(printenv radarr_release_size)"

    # Remove any commas which may have ended up in output 
    #csv_arr_envvar_pipe=$(echo $csv_arr_envvar_pipe | tr -d ',')   # Remove all commas from original output
    #csv_arr_envvar_pipe=$(echo $csv_arr_envvar_pipe | sed 's/,//g')   # Remove all commas from original output
    csv_arr_envvar_pipe=${csv_arr_envvar_pipe//,/}                    # Remove all commas from original output

    # Convert any pipes into commas
    #csv_arr_envvar_csv="$(echo "$csv_arr_envvar_pipe" | tr '|' ',')"
    #csv_arr_envvar_csv="$(echo "$csv_arr_envvar_pipe" | sed 's/|/,/g')"
    csv_arr_envvar_csv=${csv_arr_envvar_pipe//|/,}
    echo "$csv_arr_envvar_csv" >> "$LOG_ARR_CSV"
}


##### PARSE COMMAND LINE INPUT ####################################################################

# CLI ARGUMENTS
# CLI arguments will take precedence if the corresponding env var is also set
#   - help (output help/usage message)
#   - debug (outputs some additional info to screen to help with testing)
#   - tdarr_url (incl http and port) (overrides hardcoded URL in script)
#   - event_type (overrides any sonarr_eventtype or radarr_eventtype)
#   - sonarr_eventtype (overrides env var, if set)
#   - radarr_eventtype (overrides env var, if set)
#   - filepath (overrides any sonarr_episodefile_path or radarr_moviefile_path)
#   - sonarr_episodefile_path (overrides env var, if set)
#   - radarr_moviefile_path (overrides env var, if set)
#   - library_id (explicitly specifying CLI library_id will override library ID selection logic in script)
#   - logfile (overrides hardcoded log file path)


# For getopt details, see Obsidian notes and/or: https://stackoverflow.com/a/29754866
# Test whether enhanced getopt is available (i.e. `getopt --test` has exit code `4`)
getopt --test || [ "${PIPESTATUS[0]}" -ne 4 ] && msg_error "Enhanced getopt not available!" && exit 1

# DEFINE COMMAND LINE OPTIONS
# Options with REQUIRED arg = follow with `:` | Options with OPTIONAL arg = follow with `::`
LONGOPTS=help,debug,tdarr_url:,event_type:,sonarr_eventtype:,radarr_eventtype:,filepath:,sonarr_episodefile_path:,radarr_moviefile_path:,library_id:,logfile:
#OPTIONS=a:b:c:
# CALL GETOPT TO PARSE OUT INPUT
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
# If last command has exit status !=0 then terminate script
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Reorder command line args to have the `option` args first
eval set -- "$PARSED"

# Define default arg values since using `nounset`
CLI_HELP=0; CLI_DEBUG=0; CLI_LOGFILE='';
CLI_TDARR_URL=''; CLI_LIB_ID='';
CLI_EVENT_TYPE=''; CLI_SONARR_EVENTTYPE=''; CLI_RADARR_EVENTTYPE=''
CLI_FILEPATH=''; CLI_SONARR_EPISODEFILE_PATH=''; CLI_RADARR_MOVIEFILE_PATH=''

while true ; do
    case "$1" in
        --help) CLI_HELP=1 ; shift ;;
        --debug) CLI_DEBUG=1 ; shift ;;
        --logfile) CLI_LOGFILE="$2" ; shift 2 ;;
        --tdarr_url) CLI_TDARR_URL="$2" ; shift 2 ;;
        --library_id) CLI_LIB_ID="$2" ; shift 2 ;;
        --event_type) CLI_EVENT_TYPE="$2" ; shift 2 ;;
        --sonarr_eventtype) CLI_SONARR_EVENTTYPE="$2" ; shift 2 ;;
        --radarr_eventtype) CLI_RADARR_EVENTTYPE="$2" ; shift 2 ;;
        --filepath) CLI_FILEPATH="$2" ; shift 2 ;;
        --sonarr_episodefile_path) CLI_SONARR_EPISODEFILE_PATH="$2" ; shift 2 ;;
        --radarr_moviefile_path) CLI_RADARR_MOVIEFILE_PATH="$2" ; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

##### HELP / USAGE MESSAGE #######################################################################

if [[ $CLI_HELP -eq 1 ]]; then
    echo
    echo "HELP / USAGE ================================================"
    echo "This script can be added to sonarr/radarr as a custom script and triggered 'on file import' and 'on file upgrade'."
    echo 
    echo "It is designed to work with the sonarr/radarr environment variables which are set when the custom script is called so it will pick"
    echo "up the video file path from sonarr/raddar env vars and pass the path to tdarr."
    echo "It will also check the video codec (from sonarr/radarr env var) and will not trigger tdarr if the video is already x265."
    echo
    echo "Tdarr container volume mappings for media directories should match the volume mappings for the sonarr/radarr containers."
    echo "A tdarr library should be created for each main media directory and the library's ID should be updated in this file's variables."
    echo "The library ID tells tdarr which library the file belongs to, i.e. the tdarr library which is set up to acces the file's location."
    echo 
    echo "The script can also be used with command line arguments instead of the sonarr/radarr environment variables - allows us to use the"
    echo "script 'as is' directly on the docker host by simply passing a file path for tdarr to process. Any CLI arguments used will take"
    echo "priority over environment variables (if they also exist at the same time)."
    echo "If using on host, pass the fully qualified file path wrt root - the script will dynamically re-write the path to match tdarr's"
    echo "directories so that the video file is still found by tdarr."
    echo 
    echo "EXAMPLES"
    echo "Sonarr/Raddar Example (setting the env vars before scrpt is called to replicate sonarr/radarr behaviour):"
    echo "    sonarr_eventtype=Import sonarr_episodefile_path='/storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi' /home/ryan/scripts/docker/scripts/torrents/custom_scripts/tdarr/notify-tdarr.sh"
    echo "Use On Docker Host By Passing Target File Path Only (MUST pass full path, no relative paths allowed)"
    echo "    /home/ryan/scripts/docker/scripts/torrents/custom_scripts/tdarr/notify-tdarr.sh --debug --filepath /storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi"  
    echo
    echo "CLI Arguments"
    echo "(If used, these will take precedence over any sonarr/radarr environment variables.)"
    echo "   --help                                     Output this help/usage message"
    echo "   --debug                                    Outputs additional info to screen to help with testing"
    echo "   --tdarr_url \"http://192.168.0.10:8265\"   Overrides hardcoded URL in script"
    echo "   --event_type \"string\"                    Override sonarr_eventtype or radarr_eventtype cli args"
    echo "   --sonarr_eventtype \"string\"              Overrides sonarr_eventtype env var (if set)"
    echo "   --radarr_eventtype \"string\"              Overrides radarr_eventtype env var (if set)"
    echo "   --filepath \"path\"                        Overrides sonarr_episodefile_path or radarr_moviefile_path cli args"
    echo "   --sonarr_episodefile_path \"path\"         Overrides sonarr_episodefile_path env var (if set)"
    echo "   --radarr_moviefile_path \"path\"           Overrides radarr_moviefile_path env var (if set)"
    echo "   --library_id \"string\"                    Will override library ID selection logic in script"
    echo "   --logfile \"path\"                         Overrides hardcoded log file path"
    echo
    echo "Heavily modified from original at: https://github.com/hollanbm/tdarr_autoscan"
    echo "============================================================="
    echo
    exit 0
fi



##### VARIABLES ###################################################################################

# Function to indent any command output for looking nice
function indent() { sed 's/^/    /'; }

# SET LOG DIRECTORY
if [[ $HOSTSYSTEM == "docker" ]]; then
    LOGDIR="/downloads/_logs"
else
    LOGDIR="/storage/scratchpad/downloads/_torrents/_logs"
fi

# Log environment vars - helps with debugging
LOG_ARR_VARS="$LOGDIR/_tdarr-notified-arr-inputs.txt"
LOG_ARR_CSV="$LOGDIR/_tdarr-notified-arr-inputs.csv"
LOG_LAST_ENVVARS="$LOGDIR/_tdarr-notified-lastrun-envvars.txt"
debug_log_all_envars

# MISC
DEBUG=${CLI_DEBUG:-0} 
DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"
#DATETIMEUNIX="$(date +%s)"

# LOGFILE
LOGFILE="$LOGDIR/_tdarr-notified.txt"
# Override logfile path if explicitly defined in CLI arg.
LOGFILE=${CLI_LOGFILE:-"$LOGFILE"}

# Set CSV log file using LOGFILE as basis - swap extension to .csv
LOGFILE_CSV="${LOGFILE%.txt}.csv"

# TDARR URL (allow override with CLI arg)
if [[ $HOSTSYSTEM == "docker" ]]; then
    TDARR_URL=${CLI_TDARR_URL:-"http://tdarr:8265"}         # Works if sonarr/radarr on same docker network as tdarr
else
    TDARR_URL=${CLI_TDARR_URL:-"http://192.168.0.10:8265"}  # Use IP or FQDN if sonarr/radarr and tdarr are not on same docker network, or if running from host
fi

# LIBRARY IDS
# The path used for the respective tdarr libraries must correspond to the same path sent from radarr/sonarr.
# If the tdarr library path does not correspond then tdarr will not be able to find the file to process.
# We could use a library for all media and dynamically convert sonarr/radarr paths into paths recognisable by tdarr
# but that would prevent our tdarr flow from calling the 'sonarr/Radarr Renaming File' plugin since the tdarr
# converted file would not be in a path which sonarr/radarr recognises.
tv_library_id="N8vh3tL29"
movies_library_id="FdBrWMIB4"
movies4k_library_id="Dhh0m6yQ5"
allvids_library_id="CmPfVtR3u"

# EVENT TYPE
# Get env vars from sonarr/radarr
#ENV_SONARR_EVENTTYPE=${!sonarr_eventtype}   # Alt method using bash built-in approach (didn't work well in containers)
ENV_SONARR_EVENTTYPE="$(printenv sonarr_eventtype)"
ENV_RADARR_EVENTTYPE="$(printenv radarr_eventtype)"
# Priority order of event type inputs (highest priority first)
# - CLI arg: CLI_EVENT_TYPE
# - CLI arg: CLI_SONARR_EVENTTYPE
# - CLI arg: CLI_RADARR_EVENTTYPE
# - Env var: ENV_SONARR_EVENTTYPE
# - Env var: ENV_RADARR_EVENTTYPE
# Set event type from prioritised options
EVENT_TYPE=${CLI_EVENT_TYPE:-${CLI_SONARR_EVENTTYPE:-${CLI_RADARR_EVENTTYPE:-${ENV_SONARR_EVENTTYPE:-"$ENV_RADARR_EVENTTYPE"}}}}

# Log variable to track whether triggered by sonarr or radarr - just for info in final log
if [[ -n "$ENV_SONARR_EVENTTYPE" ]]; then
    SCRIPT_TRIGGERED_BY="sonarr"
elif [[ -n "$ENV_RADARR_EVENTTYPE" ]]; then
    SCRIPT_TRIGGERED_BY="radarr"
else
    SCRIPT_TRIGGERED_BY="other"
fi

# FILE PATH
ENV_SONARR_EPISODEFILE_PATH="$(printenv sonarr_episodefile_path)"
ENV_RADARR_MOVIEFILE_PATH="$(printenv radarr_moviefile_path)"
# Priority order of file path inputs (highest priority first)
# - CLI arg: CLI_FILEPATH
# - CLI arg: CLI_SONARR_EPISODEFILE_PATH  =  CLI_RADARR_MOVIEFILE_PATH
# - Env var: ENV_SONARR_EPISODEFILE_PATH  =  ENV_RADARR_MOVIEFILE_PATH
# Raise error if conflicting file paths provided
if [[ -n "$ENV_SONARR_EPISODEFILE_PATH" && -n "$ENV_RADARR_MOVIEFILE_PATH" ]]; then
    echo "ERROR - Both sonarr and radarr file path environment variables provided - unclear which is the target file. Exiting!"; exit 1
fi
if [[ -n "$CLI_SONARR_EPISODEFILE_PATH" && -n "$CLI_RADARR_MOVIEFILE_PATH" ]]; then
    echo "ERROR - Both sonarr and radarr file path CLI arguments provided - unclear which is the target file. Exiting!"; exit 1
fi
if [[ -n "$CLI_FILEPATH" && (-n "$CLI_SONARR_EPISODEFILE_PATH" || -n "$CLI_RADARR_MOVIEFILE_PATH") ]]; then
    echo "ERROR - Filepath CLI argument provided but sonarr and/or radarr file path CLI argument also provided - unclear which is the target file. Exiting!"; exit 1
fi
# Set file path from prioritised options
FILE_PATH=${CLI_FILEPATH:-${CLI_SONARR_EPISODEFILE_PATH:-${CLI_RADARR_MOVIEFILE_PATH:-${ENV_SONARR_EPISODEFILE_PATH:-"$ENV_RADARR_MOVIEFILE_PATH"}}}}

# VIDEO CODEC
# We should only receive the codec from sonarr/radarr and never both at the same time so should be safe to set the codec
# variable to match one or the other depending on which exists.
ENV_SONARR_VID_CODEC="$(printenv sonarr_episodefile_mediainfo_videocodec)"
ENV_RADARR_VID_CODEC="$(printenv radarr_moviefile_videocodec)"
VIDEO_CODEC=${ENV_SONARR_VID_CODEC:-"$ENV_RADARR_VID_CODEC"}

##### PATH TRANSLATIONS ###########################################################################

# FILE PATH TRANSLATION
# We're not using any path translation as our sonarr/radarr paths are identical to our tdarr paths.
#if [[ -n "${TDARR_PATH_TRANSLATE}" ]]; then
#  FILE_PATH=$(echo "$FILE_PATH" | sed "s|${TDARR_PATH_TRANSLATE}|")
#fi

# CONVERT FILE PATH IF RUNNING FROM HOST
# Don't really need the if statement as we could/should remap any time the input file path matches these strings.
#if [[ $HOSTSYSTEM == "host" ]]; then
    # Using sed
    #FILE_PATH=$(echo "$FILE_PATH" | sed "s|/storage/Media/Video/TV|/tv|")
    #FILE_PATH=$(echo "$FILE_PATH" | sed "s|/storage/Media/Video/Movies|/movies|")
    #FILE_PATH=$(echo "$FILE_PATH" | sed "s|/storage/Media/Video/Movies_4K|/movies_4k|")
    # Using parameter substitution
    FILE_PATH=${FILE_PATH//"/storage/Media/Video/TV/"/"/tv/"}
    FILE_PATH=${FILE_PATH//"/storage/Media/Video/Movies/"/"/movies/"}
    FILE_PATH=${FILE_PATH//"/storage/Media/Video/Movies_4K/"/"/movies_4k/"}
    FILE_PATH=${FILE_PATH//"/storage/Media/Video/Misc/"/"/all_vids/Misc/"}
#fi


##### ASSIGN LIBRARY ID ###########################################################################

if [[ "$FILE_PATH" == "/tv/"* ]]; then
    TDARR_LIBRARY_NAME="TV"        # Just for logging, so don't need to lookup IDs when reviewing logs 
    TDARR_DB_ID="${tv_library_id}"
elif [[ "$FILE_PATH" == "/movies/"* ]]; then
    TDARR_LIBRARY_NAME="Movies"        # Just for logging, so don't need to lookup IDs when reviewing logs 
    TDARR_DB_ID="${movies_library_id}"
elif [[ "$FILE_PATH" == "/movies_4k/"* ]]; then
    TDARR_LIBRARY_NAME="Movies_4K"        # Just for logging, so don't need to lookup IDs when reviewing logs 
    TDARR_DB_ID="${movies4k_library_id}"
elif [[ "$FILE_PATH" == "/all_vids/"* ]]; then
    TDARR_LIBRARY_NAME="All-Vids"        # Just for logging, so don't need to lookup IDs when reviewing logs 
    TDARR_DB_ID="${allvids_library_id}"
elif [[ "$EVENT_TYPE" == "Test"* ]]; then
    # When setting up in sonarr/radarr, the 'test' button in the GUI triggers script with event type = Test but no
    # file path. If we continue from here we will end up with an error so want to exit cleanly so that there is a 
    # positive confirmation of script working when test button is pressed.
    echo "Sonarr/Radarr Event Type = Test but no file path provided. Script likely being triggered by Sonarr/Radarr GUI 'Test' button. Exiting cleanly"
    exit 0
else
    echo "ERROR - File path does not match any of the configured tdarr library paths - can not call tdarr API!"
    exit 1
fi
# Override library ID with CLI arg if provided
TDARR_DB_ID=${CLI_LIB_ID:-"$TDARR_DB_ID"} 
# Or we could loop through all library IDs and send API call for each one. If target a library but the file path is not in that library
# then there is no action taken so no issues with trying them all. 
# e.g. https://github.com/hollanbm/tdarr_autoscan/issues/2


##### SET UP API COMMAND #########################################################################

# SET PAYLOAD FOR TDARR API CALL
if [[ -z "$TDARR_DB_ID" ]]; then
    echo "ERROR - Tdarr library ID not set, can not create valid API payload, exiting!"
    exit 1
else
    PAYLOAD="{\"data\": {\"scanConfig\": {\"dbID\": \"${TDARR_DB_ID}\", \"arrayOrPath\": [\"$FILE_PATH\"], \"mode\": \"scanFolderWatcher\" }}}"
fi

# CREATE TDARR API COMMAND
unset TDARR_API_CMD
TDARR_API_CMD=("curl --request POST")
TDARR_API_CMD+=("--url '${TDARR_URL}/api/v2/scan-files'")
TDARR_API_CMD+=("--header 'content-type: application/json'")
TDARR_API_CMD+=("--data '$PAYLOAD'")
TDARR_API_CMD+=("--location --insecure")
TDARR_API_CMD+=("--silent")

##### CHECK CODEC #################################################################################

# If video codec is already x265 then don't notify tdarr
if [[ "$VIDEO_CODEC" == "x265" || "$VIDEO_CODEC" == "265" ]]; then
    SKIP_ALREADY_HEVC=1
fi


##### LOGGING #####################################################################################

# Setup output handler to write to log file and also show on screen if DEBUG=1
output_handler() {
    if [ "$DEBUG" -eq 1 ]; then
        tee -a "$LOGFILE"
    else
        tee -a "$LOGFILE" >/dev/null
    fi
}

# This is the same as the debugging output but logs to file instead of screen
{
echo   
echo "DATETIME = $DATETIME"
echo "SCRIPT_TRIGGERED_BY = $SCRIPT_TRIGGERED_BY"
echo
echo "--- debug ---"
echo "CLI_DEBUG = $CLI_DEBUG"
echo "DEBUG = $DEBUG"
echo
echo "--- log file ---"
echo "CLI_LOGFILE = $CLI_LOGFILE"
echo "LOGFILE = $LOGFILE"
echo "LOGFILE_CSV = $LOGFILE_CSV"
echo
echo "--- tdarr URL ---"
echo "CLI_TDARR_URL = $CLI_TDARR_URL"
echo "TDARR_URL = $TDARR_URL"
echo
echo "--- event type ---"
echo "Env Var - radarr_eventtype = $ENV_RADARR_EVENTTYPE"
echo "Env Var - sonarr_eventtype = $ENV_SONARR_EVENTTYPE"
echo "CLI_RADARR_EVENTTYPE = $CLI_RADARR_EVENTTYPE"
echo "CLI_SONARR_EVENTTYPE = $CLI_SONARR_EVENTTYPE"
echo "CLI_EVENT_TYPE = $CLI_EVENT_TYPE"
echo "EVENT_TYPE = $EVENT_TYPE" 
echo
echo "--- file path ---"
echo "TDARR_PATH_TRANSLATE = $TDARR_PATH_TRANSLATE"
echo "Env Var - radarr_moviefile_path = $ENV_RADARR_MOVIEFILE_PATH"
echo "Env Var - sonarr_episodefile_path = $ENV_SONARR_EPISODEFILE_PATH"
echo "CLI_RADARR_MOVIEFILE_PATH = $CLI_RADARR_MOVIEFILE_PATH"
echo "CLI_SONARR_EPISODEFILE_PATH = $CLI_SONARR_EPISODEFILE_PATH"
echo "CLI_FILEPATH = $CLI_FILEPATH"
echo "FILE_PATH = $FILE_PATH"
echo
echo "--- tdarr library id ---"
echo "CLI_LIB_ID = $CLI_LIB_ID"
echo "TDARR_DB_ID = $TDARR_DB_ID"
echo "TDARR_LIBRARY_NAME = $TDARR_LIBRARY_NAME"   
echo 
echo "--- video codec ---"
echo "Env Var - sonarr_episodefile_mediainfo_videocodec = $ENV_SONARR_VID_CODEC"
echo "Env Var - radarr_moviefile_videocodec = $ENV_RADARR_VID_CODEC"
echo "VIDEO_CODEC = $VIDEO_CODEC"
echo "SKIP_ALREADY_HEVC = $SKIP_ALREADY_HEVC"
echo
echo "--- misc ---"   
echo
echo "--- api command ---"
echo "PAYLOAD = "
echo "$PAYLOAD" | indent
echo "TDARR_API_CMD = "
echo "${TDARR_API_CMD[*]}" | indent
echo
echo "============================================================="
echo
} | output_handler
#} >> "$LOGFILE"

if [[ -n "$LOGFILE_CSV" ]]; then
    # CSV Fields:
    #   DATETIME
    #   SCRIPT_TRIGGERED_BY
    #   CLI_DEBUG
    #   DEBUG
    #   CLI_LOGFILE
    #   LOGFILE
    #   LOGFILE_CSV
    #   CLI_TDARR_URL
    #   TDARR_URL
    #   ENV_RADARR_EVENTTYPE
    #   ENV_SONARR_EVENTTYPE
    #   CLI_RADARR_EVENTTYPE
    #   CLI_SONARR_EVENTTYPE
    #   CLI_EVENT_TYPE
    #   EVENT_TYPE
    #   TDARR_PATH_TRANSLATE
    #   ENV_RADARR_MOVIEFILE_PATH
    #   ENV_SONARR_EPISODEFILE_PATH
    #   CLI_RADARR_MOVIEFILE_PATH
    #   CLI_SONARR_EPISODEFILE_PATH
    #   CLI_FILEPATH
    #   FILE_PATH
    #   CLI_LIB_ID
    #   TDARR_DB_ID
    #   TDARR_LIBRARY_NAME
    #   ENV_SONARR_VID_CODEC
    #   ENV_RADARR_VID_CODEC
    #   VIDEO_CODEC
    #   SKIP_ALREADY_HEVC
    csv_logging_pipe="$DATETIME"
    csv_logging_pipe="${csv_logging_pipe}|$SCRIPT_TRIGGERED_BY"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_DEBUG"
    csv_logging_pipe="${csv_logging_pipe}|$DEBUG"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_LOGFILE"
    csv_logging_pipe="${csv_logging_pipe}|$LOGFILE"
    csv_logging_pipe="${csv_logging_pipe}|$LOGFILE_CSV"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_TDARR_URL"
    csv_logging_pipe="${csv_logging_pipe}|$TDARR_URL"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_RADARR_EVENTTYPE"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_SONARR_EVENTTYPE"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_RADARR_EVENTTYPE"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_SONARR_EVENTTYPE"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_EVENT_TYPE"
    csv_logging_pipe="${csv_logging_pipe}|$EVENT_TYPE"
    csv_logging_pipe="${csv_logging_pipe}|$TDARR_PATH_TRANSLATE"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_RADARR_MOVIEFILE_PATH"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_SONARR_EPISODEFILE_PATH"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_RADARR_MOVIEFILE_PATH"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_SONARR_EPISODEFILE_PATH"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_FILEPATH"
    csv_logging_pipe="${csv_logging_pipe}|$FILE_PATH"
    csv_logging_pipe="${csv_logging_pipe}|$CLI_LIB_ID"
    csv_logging_pipe="${csv_logging_pipe}|$TDARR_DB_ID"
    csv_logging_pipe="${csv_logging_pipe}|$TDARR_LIBRARY_NAME"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_SONARR_VID_CODEC"
    csv_logging_pipe="${csv_logging_pipe}|$ENV_RADARR_VID_CODEC"
    csv_logging_pipe="${csv_logging_pipe}|$VIDEO_CODEC"
    csv_logging_pipe="${csv_logging_pipe}|$SKIP_ALREADY_HEVC"

    # Remove any commas which may have ended up in output 
    #csv_logging_pipe=$(echo $csv_logging_pipe | tr -d ',')   # Remove all commas from original output
    #csv_logging_pipe=$(echo $csv_logging_pipe | sed 's/,//g')   # Remove all commas from original output
    csv_logging_pipe=${csv_logging_pipe//,/}                    # Remove all commas from original output

    # Convert any pipes into commas
    #csv_logging_csv="$(echo "$csv_logging_pipe" | tr '|' ',')"
    #csv_logging_csv="$(echo "$csv_logging_pipe" | sed 's/|/,/g')"
    csv_logging_csv=${csv_logging_pipe//|/,}
    echo "$csv_logging_csv" >> "$LOGFILE_CSV"
fi

##### RUN API COMMAND #############################################################################

if [[ $SKIP_ALREADY_HEVC -eq 1 ]]; then
    echo "Video already x265 - not notifying tdarr"
    echo; exit 0
fi

if [[ "$EVENT_TYPE" != "Test" ]]; then
    echo "Making API call...!"
    # shellcheck disable=SC2294
    eval "${TDARR_API_CMD[@]}"
else
    echo "Event type is 'Test', not sending tdarr API command"
fi

echo