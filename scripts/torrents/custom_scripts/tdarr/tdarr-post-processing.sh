#!/bin/bash
#set -o pipefail -o nounset

############################################################################################################################################

# This file is executed at the end of the processing flow to log the converted file's details (and original file details) after it is processed.

# Map this directory to the tdarr docker container:
#      - /home/ryan/scripts/docker/scripts/torrents/custom_scripts:/custom-scripts

# • We can add a 'Call CLI' node to our tdarr flow to enable us to analyse file details
# • Some command line arguments for the 'Call CLI' node are listed below - identfied from looking through tdarr_plugins github code:
#   https://github.com/HaveAGitGat/Tdarr_Plugins
#   Check code for additional args available e.g. there are some for bit rate, etc
# • All 'inputFileObj' can be replaced with 'originalLibraryFile' to get details of original file input to flow
# • To test args, add new ones to end of existing list in node and uncomment 'LOG ALL CLI ARGS' code below to save args to file for review.

# Args to use in our script
#   "{{{args.inputFileObj._id}}}"                                               = File Path (including filename) Of File Flowing Into Node
#   "{{{args.inputFileObj.file_size}}}"                                         = File Size Of File Flowing Into Node (in MB)
#   "{{{args.inputFileObj.ffProbeData.format.duration}}}"                       = returns precise duration to 6dp of current working file
# Other args (not found a reason to use yet)
#   "{{{args.platform_arch_isdocker}}}"                                         = confirms if running in docker e.g. returns 'linux_x64_docker_true'
#   "{{{args.inputFileObj.file}}}"                                              = File Path (including filename) Of File Flowing Into Node (only used once in code)
#   "{{{args.inputFileObj.meta.Duration}}}"                                     = returns duration rounded to nearest second of original file, sometimes returns in hh:mm:ss format so result may need post-processing
#   "{{{args.inputFileObj.container}}}"                                         = returns file container e.g. mkv
#   "{{{args.inputFileObj.video_codec_name}}}"                                  = returns video codec e.g. h264, hevc. We already obtain in script below from analysing file.
#   "{{{args.inputFileObj.ffProbeData.streams.length}}}"                        = returns number of streams in file, but looks inconsistent with returning any result and breaks subsequent if nothing returned
#   "{{{args.inputFileObj.DB}}}"                                                = returns library ID
# Not useful args
#   "{{{args.inputFileObj.ffProbeData.stream}}}"                                = no response but was hoping for codec details
#   "{{{args.inputFileObj.meta.length}}}"                                       = nothing, failed any afterwards
#   "{{{args.inputFileObj.ffProbeData}}}"                                       = returns '[object Object]'
#   "{{{args.inputFileObj.ffProbeData.streams[i].codec_name}}}"                 = there is likely an arg which does return this info but this one doesn't seem to return anything, and may block remaining args being output (not fully investigated so worth re-trying in future ifvalue needed)
#   "{{{args.inputFileObj.ffProbeData.streams[i].profile}}}"                    = there is likely an arg which does return this info but this one doesn't seem to return anything, and may block remaining args being output (not fully investigated so worth re-trying in future ifvalue needed)
#   "{{{args.inputFileObj.ffProbeData.streams[i].bits_per_raw_sample}}}"        = there is likely an arg which does return this info but this one doesn't seem to return anything, and may block remaining args being output (not fully investigated so worth re-trying in future ifvalue needed)
#   "{{{args.inputFileObj.ffProbeData.stream.codec_name}}}"                     = no response and block subsequent args
# Args to try:
#   "{{{args.inputFileObj.ffProbeData.stream.codec_name}}}"
#   "{{{args.inputFileObj.ImediaInfo.duration}}}"

# Rough work to populate our CLI node args...
#"{{{args.inputFileObj._id}}}" "{{{args.inputFileObj.file_size}}}" "{{{args.originalLibraryFile._id}}}" "{{{args.originalLibraryFile.file_size}}}" 
#   "{{{args.inputFileObj.ffProbeData.format.duration}}}" "{{{args.originalLibraryFile.ffProbeData.format.duration}}}" 
#   "{{{args.inputFileObj.video_codec_name}}}" "{{{args.originalLibraryFile.video_codec_name}}}" 
#   "{{{args.inputFileObj.ImediaInfo.duration}}}" 

#"{{{args.inputFileObj._id}}}" "{{{args.inputFileObj.file_size}}}" "{{{args.originalLibraryFile._id}}}" "{{{args.originalLibraryFile.file_size}}}" "{{{args.inputFileObj.ffProbeData.format.duration}}}" "{{{args.originalLibraryFile.ffProbeData.format.duration}}}" "{{{args.inputFileObj.video_codec_name}}}" "{{{args.originalLibraryFile.video_codec_name}}}" "{{{args.inputFileObj.ImediaInfo.duration}}}" 






# In the 'Call CLI' flow node, setup this script to run after the output file is placed in it's directory either
# via the 'Replace Original File' node, or the 'Move To Directory' node. 
# Set the following options in the 'Call CLI' node:
#   - Use Custom CLI Path: Enabled
#   - Custom CLI Path: /custom-scripts/tdarr/tdarr-post-processing.sh
#   - Does Command Create Output File: Disabled
#       - IMPORTANT - Before disabling 'Does Command Create Output File' we must disable 'Output File Becomes Working File'
#           as this toggle is not visible after disabling 'Does Command Create Output File'. And if left enabled it will 
#           change the working file path and everything following the node will fail.
#   - CLI Arguments: "{{{args.inputFileObj._id}}}" "{{{args.inputFileObj.file_size}}}" "{{{args.originalLibraryFile._id}}}" "{{{args.originalLibraryFile.file_size}}}" "{{{args.inputFileObj.ffProbeData.format.duration}}}" "{{{args.originalLibraryFile.ffProbeData.format.duration}}}"
#       first 4 arguments are key metrics and were in place before adding the other so after first 4 any extra args will be placed together instead of grouping all 'inputFileObj' at the start.


############################################################################################################################################

# COMMAND SYNTAX (arguments are populated by tdarr when command executed in Flow)
# ./tdarr-post-processing.sh
#   "current-working-file-path" 
#   "current-working-file-size" 
#   "original-file-path" 
#   "original-file-size"
#   "current-working-file-duration" 
#   "original-file-duration" 

# COMMANDS FOR TESTING
# - Original source file overridden by converted file
#   ./tdarr-post-processing.sh \
#       "/storage/scratchpad/downloads/_torrents/UFC_tdarr_testing/HigherQuality/Father.Ted.s01e01.Good.Luck.Father.Ted.mkv" 
#       "412" \
#       "/storage/scratchpad/downloads/_torrents/UFC_tdarr_testing/HigherQuality/Father.Ted.s01e01.Good.Luck.Father.Ted.mkv" \
#       "650" \
#       "3612.3" \
#       "3712.3"
#
# - Converted file output to new location i.e. original source file still exists
#   ./tdarr-post-processing.sh \
#       "/storage/scratchpad/downloads/_torrents/UFC_tdarr_testing/HigherQuality/Father.Ted.s01e01.Good.Luck.Father.Ted.mkv" \
#       "277" \
#       "/storage/Media/Video/TV/Father.Ted/Season.01/Father.Ted.s01e01.Good.Luck,.Father.Ted.SDTV.XviD.AC3.2.0.avi" \
#       "350" \
#       "3612.3" \
#       "3512.3"

############################################################################################################################################

# FUNCTIONS

convert_seconds() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(( (seconds % 3600) / 60 ))
  local secs=$((seconds % 60))
  printf "%02d:%02d:%02d\n" $hours $minutes $secs
}

# Using a function for converting MB to humanreadable sizes since we don't have access to additional command line tools to do it in one line (e.g. bc)
convert_mb_to_h() {
    awk -v size="$1" '
    BEGIN {
        units[0] = "MB"; units[1] = "GB"; units[2] = "TB"; units[3] = "PB"
        i = 0
        while (size >= 1024 && i < 3) {
            size /= 1024
            i++
        }
        printf "%.2f%s", size, units[i]
    }'
}

#===========================================================================================================================================

# Update to reflect file status as it comes into this node in the flow.
FILESTATUS="Processed"

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
#PREDETAILSLOGPRETTY="$LOGDIR/_tdarr-preprocessed-pretty.txt"
POSTDETAILSLOGCSV="$LOGDIR/_tdarr-processed.csv"
POSTDETAILSLOGPRETTY="$LOGDIR/_tdarr-processed-pretty.txt"

DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"

flowfile="$1"
flowfilesizetdarr_mb="$2"
originalfile="$3"
originalfilesizetdarr_mb="$4"
flowfileduration="$5"
originalfileduration="$6"

#===========================================================================================================================================

# LOG ALL CLI ARGS - for debugging / helping identify what they are
# See note at top of post processing script for details on command line args.

#LOG_ARGS_TEMP="tdarr-args-post.tmp"
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
# INPUT FILE CALCS (FILE AT THIS POINT IN TDARR FLOW)

# Extract and display the requested information
flowfile_name="$(basename "$flowfile")"                                 # Filename (no path) 
flowfile_name_noext="${flowfile_name%.*}"                               # Filename (no path) - no extension 
#flowfile_path="$(realpath "$flowfile")"                                # Path with filename included
#flowfile_path="$(dirname  "$flowfile")"                                # Path without filename included
flowfile_path="${flowfile%/*}"                                          # Path without filename included
#flowfile_path="$(echo "$flowfile" | sed 's:/[^/]*$::')"                # Path without filename included
#flowfile_path="$(echo "$flowfile" | awk -F/ '{NF=NF-1;print}' OFS=/)"  # Path without filename included
flowfile_sizeb=$(stat -c%s "$flowfile")
flowfile_size_mb=$(awk -v bytes="$flowfile_sizeb" 'BEGIN {printf "%.2f", bytes / (1024 * 1024)}')
flowfile_sizeh=$(du -h "$flowfile" | cut -f1)


## Use ffprobe or ffmpeg to get video metadata
#flowfile_video_info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$flowfile")
## Extract video codec and resolution
#flowfile_video_codec=$(echo "$flowfile_video_info" | jq -r '.streams[0].codec_name')
#flowfile_video_width=$(echo "$flowfile_video_info" | jq -r '.streams[0].width')
#flowfile_video_height=$(echo "$flowfile_video_info" | jq -r '.streams[0].height')
#flowfile_video_resolution="${flowfile_video_width}x${flowfile_video_height}"

# Use ffmpeg to get video metadata
flowfile_video_info=$(ffmpeg -i "$flowfile" 2>&1)
# Extract video codec and resolution
flowfile_video_codec=$(echo "$flowfile_video_info" | grep -oP "Video: \K\w+")
flowfile_video_resolution=$(echo "$flowfile_video_info" | grep -oP "\d{3,}x\d{3,}")

## Use file command to get video information
#flowfile_info=$(file "$flowfile")
## Extract video codec and resolution (if available)
#flowfile_video_codec=$(echo "$flowfile_info" | grep -oP "(?<=video:)\s*\w+")
#flowfile_video_resolution=$(echo "$flowfile_info" | grep -oP "\d{3,}x\d{3,}")

# Extract creation and modification dates
#flowfile_created_date="$(stat -c %w "$flowfile" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
flowfile_modified_date="$(stat -c "%Y" "$flowfile" | xargs -I{} date -d @{} "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"

# Duration in hh:mm:ss (flowfileduration / originalfileduration)
if [[ -n $flowfileduration ]]; then
    flowfileduration_rounded=$(printf "%.0f" "$flowfileduration")
    #flowfileduration_rounded=$(echo "$flowfileduration" | awk '{printf "%.0f", $1}')
    flowfileduration_h=$(convert_seconds $flowfileduration_rounded)
fi

#===========================================================================================================================================
# ORIGINAL FILE CALCS

# PROCESS INFO ASSED BY TDARR ARGS
originalfile_name="$(basename "$originalfile")"
originalfile_name_noext="${originalfile_name%.*}"                               # Filename (no path) - no extension 
originalfile_path="${originalfile%/*}"                                          # Without filename included

# Duration in hh:mm:ss (flowfileduration / originalfileduration)
if [[ -n $originalfileduration ]]; then
    originalfileduration_rounded=$(printf "%.0f" "$originalfileduration")
    #originalfileduration_rounded=$(echo "$originalfileduration" | awk '{printf "%.0f", $1}')
    originalfileduration_h=$(convert_seconds $originalfileduration_rounded)
fi

# DO VIDEO FILE ANALYSIS IF POSSIBLE, OR GRAB METRICS FROM PRE-PROCESSING FILE
# We can only do original file analysis if the original file still exists.
# We can assume the original file has been replaced with the processed file if the two file paths match exactly (except for file extensions)
if [ "${flowfile_path}/${flowfile_name_noext}" != "${originalfile_path}/${originalfile_name_noext}" ]; then
    # New and original file paths don't match - try to extract original file details.
    original_overridden="No"
    pre_processing_output_used="No"

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

else
    original_overridden="Yes"
    # Let's try to find original file details from pre-processing CSV
    if grep -q "$originalfile_name" "$PREDETAILSLOGCSV"; then
        pre_processing_output_used="Yes"
        # CSV field list:
        #   1. Script Triggered
        #   2. File Status
        #   3. Original File
        #   4. Original Filename
        #   5. Original File Path
        #   6. Original File Size From Tdarr (MB)
        #   7. Original File Size Calculated (MB)
        #   8. Original File size Calculated (human readable)
        #   9. Original Video Codec
        #   10. Original Video Resolution
        #   11. Original Created Date
        #   12. Original Last Modified Date
        originalfile_size_mb=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $7}')
        originalfile_sizeh=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $8}')
        originalfile_video_codec=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $9}')
        originalfile_video_resolution=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $10}')
        #originalfile_created_date=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $11}')
        originalfile_modified_date=$(grep "$originalfile_name" "$PREDETAILSLOGCSV" | tail -n 1 | awk -F ',' '{print $12}')
    else
        pre_processing_output_used="Attempted But Not Found"
    fi
fi


#===========================================================================================================================================
# DIFFERENCE CALCS

size_reduction_tdarr_mb=$(awk -v num1="$flowfilesizetdarr_mb" -v num2="$originalfilesizetdarr_mb" 'BEGIN {printf "%.2f", num2 - num1}')
size_reduction_tdarr_perc=$(awk -v num1="$flowfilesizetdarr_mb" -v num2="$originalfilesizetdarr_mb" 'BEGIN {printf "%.2f", num1 / num2 * 100}')

# For these size calculations we'd prefer not to use tdarr's supplied sizes and use our own analysed sizes.
# But we need to use the tdarr size for the original file if original no longer exists (i.e. has been overidden but converted file)
if [ "${flowfile_path}/${flowfile_name_noext}" != "${originalfile_path}/${originalfile_name_noext}" ]; then
    # New and original file paths don't match - use extracted file sizes for original (not tdarr's supplied size)
    size_reduction_calc_mb=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfile_size_mb" 'BEGIN {printf "%.2f", num2 - num1}')
    size_reduction_calc_perc=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfile_size_mb" 'BEGIN {printf "%.2f", num1 / num2 * 100}')
    # shellcheck disable=SC2086
    size_reduction_calc_h=$(convert_mb_to_h $size_reduction_calc_mb)
else
    # New and original file paths do match
    # If we were able to pull file data from pre-processing output use those values, otherwise use tdarr's supplied size for original file
    # shellcheck disable=SC2091
    #if [[ $originalfile_size_mb -gt 0 ]]; then  # can't compare floats in if statement!
    if $(awk -v num1="$originalfile_size_mb" -v num2="0" 'BEGIN {if (num1 > num2) exit 0; exit 1}'); then
        size_reduction_calc_mb=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfile_size_mb" 'BEGIN {printf "%.2f", num2 - num1}')
        size_reduction_calc_perc=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfile_size_mb" 'BEGIN {printf "%.2f", num1 / num2 * 100}')
    else
        size_reduction_calc_mb=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfilesizetdarr_mb" 'BEGIN {printf "%.2f", num2 - num1}')
        size_reduction_calc_perc=$(awk -v num1="$flowfile_size_mb" -v num2="$originalfilesizetdarr_mb" 'BEGIN {printf "%.2f", num1 / num2 * 100}')
    fi   
    # shellcheck disable=SC2086
    size_reduction_calc_h=$(convert_mb_to_h $size_reduction_calc_mb)
fi

# DURATION DIFFERENCE
if [[ -n $flowfileduration && -n $originalfileduration ]]; then
    dur_change_s=$(awk -v num1="$originalfileduration" -v num2="$originalfileduration" 'BEGIN {printf "%.2f", num2 - num1}')
    if [[ $dur_change_s -ne 0 ]]; then
        dur_change_h=$(convert_seconds $dur_change_s)
    else
        dur_change_h=0
    fi
fi

#===========================================================================================================================================
# OUTPUT

# Setup output handler to write to log file and also show on screen if DEBUG=1
output_handler() {
    if [ "$DEBUG" -eq 1 ]; then
        tee -a "$POSTDETAILSLOGPRETTY"
    else
        tee "$POSTDETAILSLOGPRETTY" >/dev/null
    fi
}

# Screen and File Pretty Output
{
echo "Script Triggered: $DATETIME"
echo "File Status: $FILESTATUS"
echo "---"
echo "File: $flowfile"
echo "Filename: ${flowfile_name:-Unknown}"
echo "File Path: ${flowfile_path:-Unknown}" 
echo "File Size From Tdarr (MB): ${flowfilesizetdarr_mb:-Unknown}"
echo "File Size Calculated (MB): ${flowfile_size_mb:-Unknown}"
echo "File size Calculated (human readable): ${flowfile_sizeh:-Unknown}"
echo "Video Codec: ${flowfile_video_codec:-Unknown}"
echo "Video Resolution: ${flowfile_video_resolution:-Unknown}"
echo "Last Modified Date: ${flowfile_modified_date:-Unknown}"
echo "Duration (s): ${flowfileduration:-Unknown}"
echo "Duration (hh:mm:ss): ${flowfileduration_h:-Unknown}"
echo "----"
echo "Original File: ${originalfile:-Unknown}"
echo "Original Filename: ${originalfile_name:-Unknown}"
echo "Original File Path: ${originalfile_path:-Unknown}" 
echo "Original File Size From Tdarr (MB): ${originalfilesizetdarr_mb:-Unknown}"
echo "The following data is only available if original file has not been replaced by processed file ..."
echo "... or if original file stats could be obtained from pre-processing analysis ..."
echo "Original File Size Calculated (MB): ${originalfile_size_mb:-Check Pre-Processing Log}"
echo "Original File size Calculated (human readable): ${originalfile_sizeh:-Check Pre-Processing Log}"
echo "Original Video Codec: ${originalfile_video_codec:-Check Pre-Processing Log}"
echo "Original Video Resolution: ${originalfile_video_resolution:-Check Pre-Processing Log}"
echo "Original Last Modified Date: ${originalfile_modified_date:-Check Pre-Processing Log}"
echo "Original Duration (s): ${originalfileduration:-Unknown}"
echo "Original Duration (hh:mm:ss): ${originalfileduration_h:-Unknown}"
echo "----"
echo "File Size Reduction - tdarr values (MB): ${size_reduction_tdarr_mb:-Unknown}"
echo "File Size Reduction % - tdarr values: ${size_reduction_tdarr_perc:-Unknown}%"
echo "File Size Reduction - calculated (MB): ${size_reduction_calc_mb:-Unknown}"
echo "File Size Reduction - calculated (human readable): ${size_reduction_calc_h:-Unknown}"
echo "File Size Reduction % - calculated: ${size_reduction_calc_perc:-Unknown}%"
echo "Duration Change - calculated (s): ${dur_change_s:-Unknown}%"
echo "Duration Change - calculated (hh:mm:ss): ${dur_change_h:-Unknown}%"
echo "----"
echo "Original File Overridden? ${original_overridden:-Unknown}"
echo "Pre-processing Output Used? ${pre_processing_output_used:-Unknown}"
echo
echo "===================================================================================================="
echo
} | output_handler
#} >> "$POSTDETAILSLOGPRETTY"

# CSV Output
# Header - split across multiple lines for readability
#   Script Triggered, File Status, 
#   File, Filename, File Path, File Size From Tdarr (MB), File Size Calculated (MB), File size Calculated (human readable),
#       Video Codec, Video Resolution, Last Nodified Date, Duration (s), Duration (hh:mm:ss)
#   Original File, Original Filename, Original File Path, Original File Size From Tdarr (MB),
#       Original File Size Calculated (MB), Original File size Calculated (human readable), Original Video Codec, 
#       Original Video Resolution, Original Last Modified Date, Original Duration (s), Original Duration (hh:mm:ss)
#   File Size Reduction - tdarr values (MB), File Size Reduction % - tdarr values, 
#       File Size Reduction - calculated (MB), File Size Reduction - calculated (human readable), File Size Reduction % - calculated
#       Duration Change - calculated (s), Duration Change - calculated (hh:mm:ss)
#   Original File Overridden?, Pre-processing Output Used?

# First process as pipe delimited to make it easier to remove all commas in case there are any commas in initial analysis output
flowfile_details_pipe="$DATETIME|$FILESTATUS"
flowfile_details_pipe="${flowfile_details_pipe}|$flowfile"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_name:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_path:-Unknown}" 
flowfile_details_pipe="${flowfile_details_pipe}|${flowfilesizetdarr_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_size_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_sizeh:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_video_codec:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_video_resolution:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfile_modified_date:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfileduration:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${flowfileduration_h:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_name:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_path:-Unknown}" 
flowfile_details_pipe="${flowfile_details_pipe}|${originalfilesizetdarr_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_size_mb:-Check Pre-Processing Log}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_sizeh:-Check Pre-Processing Log}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_video_codec:-Check Pre-Processing Log}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_video_resolution:-Check Pre-Processing Log}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfile_modified_date:-Check Pre-Processing Log}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfileduration:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${originalfileduration_h:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${size_reduction_tdarr_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${size_reduction_tdarr_perc:-Unknown}%"
flowfile_details_pipe="${flowfile_details_pipe}|${size_reduction_calc_mb:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${size_reduction_calc_h:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${size_reduction_calc_perc:-Unknown}%"
flowfile_details_pipe="${flowfile_details_pipe}|${dur_change_s:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${dur_change_h:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${original_overridden:-Unknown}"
flowfile_details_pipe="${flowfile_details_pipe}|${pre_processing_output_used:-Unknown}"

# Remove any commas which may have ended up in output 
#flowfile_details_pipe=$(echo $flowfile_details_pipe | tr -d ',')   # Remove all commas from original output
#flowfile_details_pipe=$(echo $flowfile_details_pipe | sed 's/,//g')   # Remove all commas from original output
flowfile_details_pipe=${flowfile_details_pipe//,/}                    # Remove all commas from original output

# Convert any pipes into commas
#flowfile_details_csv="$(echo "$flowfile_details_pipe" | tr '|' ',')"
#flowfile_details_csv="$(echo "$flowfile_details_pipe" | sed 's/|/,/g')"
flowfile_details_csv=${flowfile_details_pipe//|/,}
echo "$flowfile_details_csv" >> "$POSTDETAILSLOGCSV"

