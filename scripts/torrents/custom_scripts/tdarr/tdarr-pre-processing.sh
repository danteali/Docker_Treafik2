#!/bin/bash
# shellcheck disable=
#set -o pipefail -o nounset

# This file is executed at the start of the processing flow to log the original file's details before it is processed.

# Map this directory to the tdarr docker container:
#      - /home/ryan/scripts/docker/scripts/torrents/custom_scripts:/custom-scripts

# See post-processing script for notes on CLI args to use in flow node.

# In the 'Call CLI ' node, setup this script to run after the output file is placed in it's directory either
# via the 'Replace Original File' node, or the 'Move To Directory' node. 
# Set the following options in the 'Call CLI' node:
#   - Use Custom CLI Path: Enabled
#   - Custom CLI Path: /custom-scripts/tdarr/tdarr-post-processing.sh
#   - Does Command Create Output File: Disabled
#       - IMPORTANT - Before disabling 'Does Command Create Output File' we must disable 'Output File Becomes Working File'
#           as this toggle is not visible after disabling 'Does Command Create Output File'. And if left enabled it will 
#           change the working file path and everything following the node will fail.
#   - CLI Arguments: 
#           "{{{args.originalLibraryFile._id}}}" "{{{args.originalLibraryFile.file_size}}}" "{{{args.originalLibraryFile.ffProbeData.format.duration}}}"

# Update to reflect file status as it comes into this node in the flow.
FILESTATUS="Pre-Processed"

# Output some detail to screen to help with development
DEBUG=1

# Find out if we're on a docker container - only used for being able to run script from host when testing
if [ -f /.dockerenv ]; then HOSTSYSTEM="docker"; else HOSTSYSTEM="host"; fi

# Set base log directory depending on whether unning in docker host or not
if [[ $HOSTSYSTEM == "docker" ]]; then
    LOGDIR="/downloads/_logs"
else
    LOGDIR="/storage/scratchpad/downloads/_torrents/_logs"
fi

# Set log paths
PREDETAILSLOGCSV="$LOGDIR/_tdarr-preprocessed.csv"
PREDETAILSLOGPRETTY="$LOGDIR/_tdarr-preprocessed-pretty.txt"
#POSTDETAILSLOGCSV="$LOGDIR/_tdarr-processed.csv"
#POSTDETAILSLOGPRETTY="$LOGDIR/_tdarr-processed-pretty.txt"

DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"

originalfile="$1"
originalfilesizetdarr_mb="$2"
originalfileduration="$3"

#===========================================================================================================================================

# LOG ALL CLI ARGS - for debugging / helping identify what they are
# See note at top of post processing script for details on command line args.
#
#LOG_ARGS_TEMP="tdarr-args-pre.tmp"
## shellcheck disable=SC2129
#echo "" >> "$LOGDIR/$LOG_ARGS_TEMP"
#echo "$DATETIME" >> "$LOGDIR/$LOG_ARGS_TEMP"
#echo "" >> "$LOGDIR/$LOG_ARGS_TEMP"
#echo "$@" >> "$LOGDIR/$LOG_ARGS_TEMP"
#echo "" >> "$LOGDIR/$LOG_ARGS_TEMP"
#for arg in "$@"; do
#    echo "  $arg" >> "$LOGDIR/$LOG_ARGS_TEMP"
#done
#echo "" >> "$LOGDIR/$LOG_ARGS_TEMP"
#echo "==================================================================" >> "$LOGDIR/$LOG_ARGS_TEMP"

#===========================================================================================================================================
# ORIGINAL FILE CALCS

# Extract and display the requested information
originalfile_name="$(basename "$originalfile")"
originalfile_path="${originalfile%/*}"                                          # Without filename included

# Duration in hh:mm:ss 
if [[ -n $originalfileduration ]]; then
    originalfileduration_rounded=$(printf "%.0f" "$originalfileduration")
    #originalfileduration_rounded=$(echo "$originalfileduration" | awk '{printf "%.0f", $1}')
    originalfileduration_h=$(convert_seconds $originalfileduration_rounded)
fi

originalfile_sizeb=$(stat -c%s "$originalfile")
originalfile_size_mb=$(awk -v bytes="$originalfile_sizeb" 'BEGIN {printf "%.2f", bytes / (1024 * 1024)}')
originalfile_sizeh=$(du -h "$originalfile" | cut -f1)

# Use ffmpeg to get video metadata
originalfile_video_info=$(ffmpeg -i "$originalfile" 2>&1)
# Extract video codec and resolution
originalfile_video_codec=$(echo "$originalfile_video_info" | grep -oP "Video: \K\w+")
originalfile_video_resolution=$(echo "$originalfile_video_info" | grep -oP "\d{3,}x\d{3,}")

# Extract creation and modification dates
#originalfile_created_date="$(stat -c %w "$originalfile" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
originalfile_modified_date="$(stat -c "%Y" "$originalfile" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"


#===========================================================================================================================================
# OUTPUT

# Setup output handler to write to log file and also show on screen if DEBUG=1
output_handler() {
    if [ "$DEBUG" -eq 1 ]; then
        tee -a "$PREDETAILSLOGPRETTY"
    else
        tee "$PREDETAILSLOGPRETTY" >/dev/null
    fi
}

# Pretty Output
{
echo "Script Triggered: $DATETIME"
echo "File Status: $FILESTATUS"
echo "---"
echo "Original File: ${originalfile:-Unknown}"
echo "Original Filename: ${originalfile_name:-Unknown}"
echo "Original File Path: ${originalfile_path:-Unknown}" 
echo "Original File Size From Tdarr (MB): ${originalfilesizetdarr_mb:-Unknown}"
echo "Original File Size Calculated (MB): ${originalfile_size_mb:-Unknown}"
echo "Original File size Calculated (human readable): ${originalfile_sizeh:-Unknown}"
echo "Original Video Codec: ${originalfile_video_codec:-Unknown}"
echo "Original Video Resolution: ${originalfile_video_resolution:-Unknown}"
echo "Original Last Modified Date: ${originalfile_modified_date:-Unknown}"
echo "Original Duration (s): ${originalfileduration:-Unknown}"
echo "Original Duration (hh:mm:ss): ${originalfileduration_h:-Unknown}"
echo
echo "===================================================================================================="
echo
} | output_handler
#} >> "$PREDETAILSLOGPRETTY"

# CSV Output
# Header - split across multiple lines for readability
#   Script Triggered, File Status, 
#   Original File, Original Filename, Original File Path, Original File Size From Tdarr (MB),
#       Original File Size Calculated (MB), Original File size Calculated (human readable), Original Video Codec, 
#       Original Video Resolution, Original Last Modified Date, Original Duration (s), Original Duration (hh:mm:ss)

# First process as pipe delimited to make it easier to remove all commas in case there are any commas in initial analysis output
flowfile_details_pipe="$DATETIME|$FILESTATUS"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_name:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_path:-Unknown}" 
flowfile_details_pipe="${flowfile_details_pipe}|${originalfilesizetdarr_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_size_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_sizeh:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_video_codec:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_video_resolution:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_modified_date:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfileduration:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfileduration_h:-Unknown}"

# Remove any commas which may have ended up in output 
#flowfile_details_pipe=$(echo $flowfile_details_pipe | tr -d ',')   # Remove all commas from original output
#flowfile_details_pipe=$(echo $flowfile_details_pipe | sed 's/,//g')   # Remove all commas from original output
flowfile_details_pipe=${flowfile_details_pipe//,/}                    # Remove all commas from original output

# Convert any pipes into commas
#flowfile_details_csv="$(echo "$flowfile_details_pipe" | tr '|' ',')"
#flowfile_details_csv="$(echo "$flowfile_details_pipe" | sed 's/|/,/g')"
flowfile_details_csv=${flowfile_details_pipe//|/,}
echo "$flowfile_details_csv" >> "$PREDETAILSLOGCSV"


# Command for testing (run from host machine):
#./tdarr-pre-processing.sh "/storage/scratchpad/downloads/_torrents/UFC_tdarr_testing/HigherQuality/Father.Ted.s01e01.Good.Luck.Father.Ted.mkv" "412" 
# ./tdarr-pre-processing.sh "/storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi" "350"