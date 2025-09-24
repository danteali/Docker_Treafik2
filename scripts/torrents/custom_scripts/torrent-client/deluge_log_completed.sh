#!/bin/bash

# LOGS COMPLETED DOWNLOADS IN TEXT FILE
# Text file is saved at:
#   /storage/scratchpad/downloads/_torrents/
# Or inside the container in mapped volume at:
#   /downloads/_torrents_completed.txt 

# This script must live somehwere accessible by the deluge container.
# Saved in downloads directory where it doesn't need moved/recreated if deluge 'reinstalled'.
# Saved at:
#   /storage/scratchpad/downloads/_torrents/scripts/deluge_log_completed.sh
# Accessible by container at:
#   /downloads/scripts/deluge_log_completed.sh
# Copy saved in: 
#   /home/ryan/scripts/docker/scripts/torrents/deluge_log_completed.sh

# Should be setup to be triggered by the Execute plugin on completion of downloads. 
# The plugin passed three arguments to any scripts:
# "TorrentID" "Torrent Name" "Torrent Path"

torrentid=$1
torrentname=$2
torrentpath=$3

logfile="/downloads/_logs/_torrents_completed.txt"

# ====================================
# LOG COMPLETED DOWNLOADS IN TEXT FILE
# ====================================
#Add completed entry to log file
#echo "Recording download in _torrents_completed.txt..."
#echo "$torrentname      ....completed on $(date)."  >> /downloads/_logs/_torrents_completed.txt

# ====================================
# UPDATED 20250412: LOG COMPLETED FILE AND SIZE (in pipe delimited file)
# ====================================

# Get the full path of the completed torrent
completed_file="$torrentpath/$torrentname"

# Get the file size in human-readable format and bytes
filesize_human=$(du -sh "$completed_file" | cut -f1)
filesize_bytes=$(du -sb "$completed_file" | cut -f1)

# Log the details to the file
echo "Recording download in $logfile..."
echo "$(date +'%Y-%m-%d %H:%M:%S')|$torrentname|$filesize_human|$filesize_bytes" >> "$logfile"

