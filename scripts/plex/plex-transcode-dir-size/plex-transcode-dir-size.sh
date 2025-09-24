#!/bin/bash

DATETIME=$(date +"%d/%m/%Y %H:%M:%S")

# Specify where output file should be saved. This should be where nodeexporter looks for the files.
OUTPUTFILE=/storage/scratchpad/downloads/transcode-dir-size.csv

# Add list of directories to be monitored. 
DIRECTORY="/storage/Docker/plex/transcode/Transcode/"

SIZE=$(du -sm $DIRECTORY | awk '{print $1}')
		
echo "$DIRECTORY,$DATETIME,$SIZE" >> $OUTPUTFILE