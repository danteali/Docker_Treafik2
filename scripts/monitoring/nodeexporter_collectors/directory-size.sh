#!/bin/bash

# https://www.robustperception.io/monitoring-directory-sizes-with-the-textfile-collector

# Set temp files for working
# $$ returns current process PID, used below to create temp file.
# $(basename "$0") returns filename of this script
# If we want to be even tidier we could also remove extension with: ${FILENAME%%.*}
THISFILENAME=$(basename "$0")
TEMPFILE="/tmp/${THISFILENAME%%.*}.$$"
DATETIME="$(date +%Y%m%d_%H%M%S)"

# Specify where output file should be saved. This should be where nodeexporter looks for the files.
OUTPUTFILE="/storage/Docker/nodeexporter/textfile_collector/directory_size.prom"

BINDU="/usr/bin/du"

# Add list of directories to be monitored. 
DIRECTORIES=(
             "/storage/Media/Audio"
             "/storage/Media/Books"
             "/storage/Media/Comics"
             "/storage/Media/Video/Movies"*
             "/storage/Media/Video/Misc"
             "/storage/Media/Video/TV"
             "/storage/scratchpad"
             "/storage/scratchpad/frigate"
             "/storage/Backup"
             "/storage/Docker"
             "/home/ryan" 
             )

echo "#$DATETIME" > "$TEMPFILE"

for directory in "${DIRECTORIES[@]}"; do
    sudo $BINDU -sb "$directory" | sed -ne 's/^\([0-9]\+\)\t\(.*\)$/node_directory_size_bytes{directory="\2"} \1/p' >> "$TEMPFILE"
done

mv "$TEMPFILE" "$OUTPUTFILE"

#rm "$TEMPFILE"
