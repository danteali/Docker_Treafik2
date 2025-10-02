#!/bin/bash

# - REMOVES COMPLETED DOWNLOADS FROM TRANSMISSION
# - LOGS COMPLETED DOWNLOADS IN TEXT FILE
# - TRIGGERS SONARR AND RADARR SCANS

# This script must live somehwere accessible by the transmission container.
# Previously saved inside the /storage/transmission/data directory but now saved in the
# downloads dirctory where it doesn't need moved/recreated if transmission 'reinstalled'.
#     docker exec torr_transmission /downloads/scripts/transmission_remove_completed.sh

# Remember to save a backup copy of this script in:
# /home/ryan/scripts/docker/scripts/torrents/api_interaction

# This script is triggered from: /home/ryan/scripts/docker/scripts/torrents/torrents/transmission_monitor.sh
# Which is run every X minutes via crontab.
# The crontab script's primary task is to check that the VPN is still up and close transmission if
# it is not # connected. But it also calls this script.



# Get sensitive info from .conf file
CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
typeset -A secrets    # Define array to hold variables 
while read line; do
  if echo $line | grep -F = &>/dev/null; then
    varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
  fi
done < $CONF_DIR/transmission_remove_completed.conf
#echo ${secrets[USERNAME]}; echo ${secrets[PASSWORD]}; 
#echo ${secrets[SONARR_API_KEY]}; echo ${secrets[RADARR_API_KEY]}

#USERNAME=${secrets[USERNAME]}
#PASSWORD=${secrets[PASSWORD]}
USERNAME=$(cat /run/secrets/transmission_rpc_username)
PASSWORD=$(cat /run/secrets/transmission_rpc_password)

SONARR_API_KEY=${secrets[SONARR_API_KEY]}
RADARR_API_KEY=${secrets[RADARR_API_KEY]}
COMPLETED_FOUND=0


# GET LIST OF TORRENTS FROM TRANSMISSION
TORRENTLIST=`transmission-remote --auth=$USERNAME:$PASSWORD --list | sed -e '1d;$d;s/^ *//' | cut --only-delimited --delimiter=' ' --fields=1 | sed 's/[^0-9]*//g'`
#echo $TORRENTLIST
#exit

# If testing, place quotes around password since it contains special chars e.g.
#     transmission-remote --auth=admin:"super$complex&password*" 
#this command used to work but doesn't now for some reason as completed torrents seem to have '*' beside them. So amended to the above working commmand.
#TORRENTLIST=`transmission-remote --auth=user:password --list | sed -e '1d;$d;s/^ *//' | cut --only-delimited --delimiter=' ' --fields=1`

# ===========================================================
# CREATE ARRAY OF TORRENTIDS SO WE CAN REVERSE LOOP OVER THEM
# ===========================================================
# Looping from last to first since we may be removing torrent from transmission which would impact
# the TORRENTID of subsequent items in array. e.g.
# If we have 2 items in TORRENTID list (TORRENTID=1 and TORRENTID=2) and start with TORRENTID=1
# and remove it if it is complete then when we try to process TORRENTID=2 it won't exist since it
# will now have TORRENTID=1.
ARR_TORRENTLIST=($TORRENTLIST)

#Test reverseloop
#for ((i=${#ARR_TORRENTLIST[@]}-1; i>=0; i--)); do
#  echo "${ARR_TORRENTLIST[i]}"
#done
#exit

# FOR EACH TORRENT
echo "Parsing transmission items..."
#for TORRENTID in $TORRENTLIST
for ((i=${#ARR_TORRENTLIST[@]}-1; i>=0; i--))
  do
    echo "Torrent ID: ${ARR_TORRENTLIST[i]}"
    # ======================================
    # GET TORRENT NAME AND COMPLETION STATUS
    # ======================================
    # See bottom of file for all data returned by '--info'
    #echo "* * * * * Operations on torrent ID $TORRENTID starting. * * * * *"
    DL_COMPLETED=`transmission-remote --auth=$USERNAME:$PASSWORD --torrent ${ARR_TORRENTLIST[i]} --info | grep "Percent Done: 100%"`
    DL_NAME=`transmission-remote --auth=$USERNAME:$PASSWORD --torrent ${ARR_TORRENTLIST[i]} --info | grep "Name:" | sed -e 's/  Name\: //g'`

    echo "... Name: "$DL_NAME 
    echo "... Completed Status: "$DL_COMPLETED
    #echo "$DL_NAME on $(date)."  >> /downloads/torrents_test.txt

    # ======================
    # IF TORRENT IS COMPLETE
    # ======================
    if [ "$DL_COMPLETED" != "" ]; then

      echo "Torrent ${ARR_TORRENTLIST[i]} - COMPLETED"
      COMPLETED_FOUND=1
      
      # ================================================
      # REMOVE COMPLETED TORRENTS FROM TRANSMISSION LIST
      # ================================================
      echo "Removing completed download from Transmission via transmission-remote command..."
      transmission-remote --auth=$USERNAME:$PASSWORD --torrent ${ARR_TORRENTLIST[i]} --remove

      # ====================================
      # LOG COMPLETED DOWNLOADS IN TEXT FILE
      # ====================================
      #Add completed entry to log file
      echo "Recording download in _torrents_completed.txt..."
      echo "$DL_NAME      ....completed on $(date)."  >> /downloads/_torrents_completed.txt

      
      # ===================
      # TRIGGER SONARR SCAN (For info - see bottom of file for curl response to api calls)
      # ===================
      # echo "Triggering scan via Sonarr API..."
      # Trigger sonarr directory scan to pick up new download - rememeber this is running from
      # within transmission container so sonarr port is 8989 not 9090 as exposed in proxy
      #
      # If the sonarr scan against root download directory doesn't work (it has until now) we may
      # need to add a specific scan per download and target at DL_NAME directory like the radarr
      # scan below. 
      # Until then we will pick up any TV files in the 'sweep up' scan below the loop. We used to
      # run the scan against root DL dir on each loop but this was a mistake and could cause
      # issues if we import files before we get to them in the loop and remove from transmission.
      #
      # curl http://localhost:8989/api/command -X POST -d '{"name": "downloadedepisodesscan", "path":"/downloads/"}' --header "X-Api-Key:$SONARR_API_KEY"
      # curl http://localhost:8989/api/command -X POST -d '{"name":"downloadedepisodesscan", "path":"/downloads/", "importMode":"Move"}' --header "X-Api-Key:$SONARR_API_KEY"

      # ===================
      # TRIGGER RADARR SCAN (For info - see bottom of file for curl response to api calls)
      # ===================
      echo "Triggering scan for movies using Radarr API on download directory $DL_NAME ..."
      # Radarr doesn't like scanning the root DL folder any longer so we have to target the specific
      # torrent's directory. e.g.
      # curl http://localhost:7878/api/command -X POST -d '{"name": "downloadedmoviesscan", "path": "/downloads/TheWarWithGrandpa/", "importMode":"Move"}' --header "X-Api-Key:$RADARR_API_KEY"
      # This is therefore on a per download basis as we scan the folder matching DL_NAME so we run
      # this from inside the loop against each completed download's folder. 
      #
      # Trigger radarr directory scan to pick up new download - rememeber this is running from
      # within transmission container so radarr port is 7878 not 9090 as exposed in proxy
      #
      # Create post data
      POST_DATA='{"name":"downloadedmoviesscan" , "path":"/downloads/'$DL_NAME'/", "importMode":"Move"}'
      curl http://localhost:7878/api/command -X POST -d "$POST_DATA" --header "X-Api-Key:$RADARR_API_KEY"
      POST_DATA=""      

    fi
done

# To sweep up we'll run the sonarr and radarr scans against the root download directory if any
# completed downloads were found, just in case.
if [ "$COMPLETED_FOUND" = 1 ]; then
  #SONAAR
  echo "Triggering Sonarr 'sweep up' scan on root download directory ..."
  #curl http://localhost:8989/api/command -X POST -d '{"name":"downloadedepisodesscan", "path":"/downloads/", "importMode":"Move"}' --header "X-Api-Key:$SONARR_API_KEY"

  curl http://localhost:8989/api/command?apikey=$SONARR_API_KEY \
  --insecure \
  --header "Content-Type: Application/JSON" \
  --request POST \
  --data '{"name": "DownloadedEpisodesScan", "path":"/downloads/", "importMode":"Move"}'

  #RADAAR
  echo "Triggering Radarr 'sweep up' scan on root download directory ..."
  #curl http://localhost:7878/api/command -X POST -d '{"name":"downloadedmoviesscan" , "path":"/downloads/", "importMode":"Move"}' --header "X-Api-Key:$RADARR_API_KEY"

  curl http://localhost:7878/api/command?apiKey=$RADARR_API_KEY \
  --insecure \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"name": "DownloadedMoviesScan"}'

fi


# TRANSMISSION-REMOTE --INFO
# transmission-remote --auth=$USERNAME:$PASSWORD --torrent $TORRENTID --info
# 
# NAME
#   Id: 2
#   Name: Terminator 3 Rise of The Machines (2003) [1080p]
#   Hash: b7a8e451e530117a874d22756aeb97850b74a814
#   Magnet: magnet:?xt=urn:btih:b7a8e451e530117a874d22756aeb97850b74a814&dn=Terminator%203%20Rise%20of%20The%20Machines%20%282003%29%20%5B1080p%5D&tr=udp%3A%2F%2Fopen.demonii.com%3A1337&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2Ftracker.pomf.se%3A80&tr=udp%3A%2F%2Ftracker.publicbt.com%3A80&tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80&tr=udp%3A%2F%2Ftracker.istole.it%3A80
#   Labels:
# 
# TRANSFER
#   State: Downloading
#   Location: /downloads
#   Percent Done: 0.0%
#   ETA: 0 seconds (0 seconds)
#   Download Speed: 0 kB/s
#   Upload Speed: 0 kB/s
#   Have: None (None verified)
#   Availability: 100%
#   Total size: 1.72 GB (1.72 GB wanted)
#   Downloaded: None
#   Uploaded: None
#   Ratio: None
#   Corrupt DL: None
#   Peers: connected to 16, uploading to 0, downloading from 4
# 
# HISTORY
#   Date added:       Sat Mar 20 23:40:01 2021
#   Date started:     Sat Mar 20 23:40:12 2021
#   Downloading Time: 25 seconds (25 seconds)
# 
# ORIGINS
#   Public torrent: Yes
#   Piece Count: 820
#   Piece Size: 2.00 MiB
# 
# LIMITS & BANDWIDTH
#   Download Limit: Unlimited
#   Upload Limit: Unlimited
#   Ratio Limit: Default
#   Honors Session Limits: Yes
#   Peer limit: 50
#   Bandwidth Priority: Normal


# SONARR API RESPONSE
# curl http://localhost:8989/api/command -X POST -d '{"name":"downloadedepisodesscan", "path":"/downloads/", "importMode":"Move"}' --header "X-Api-Key:84f0e7d9138f403eb78a3ba72c425113""
#
#{
#  "name": "DownloadedEpisodesScan",
#  "body": {
#    "path": "/downloads/",
#    "importMode": "move",
#    "sendUpdatesToClient": false,
#    "updateScheduledTask": true,
#    "completionMessage": "Completed",
#    "requiresDiskAccess": false,
#    "isExclusive": false,
#    "name": "DownloadedEpisodesScan",
#    "trigger": "manual",
#    "suppressMessages": false
#  },
#  "priority": "normal",
#  "status": "queued",
#  "queued": "2021-03-21T00:34:17.092642Z",
#  "trigger": "manual",
#  "state": "queued",
#  "manual": true,
#  "startedOn": "2021-03-21T00:34:17.092642Z",
#  "sendUpdatesToClient": false,
#  "updateScheduledTask": true,
#  "id": 1780520
#}

# RADARR API RESPONSE
# curl http://localhost:7878/api/command -X POST -d '{"name": "downloadedmoviesscan", "path": "/downloads/", "importMode":"Move"}' --header "X-Api-Key:97afc10bbfcc438bbd929e320a51f61e"
#
#{
#  "name": "DownloadedMoviesScan",
#  "body": {
#    "sendUpdatesToClient": false,
#    "sendUpdates": false,
#    "path": "/downloads/",
#    "importMode": "move",
#    "updateScheduledTask": true,
#    "completionMessage": "Completed",
#    "requiresDiskAccess": false,
#    "isExclusive": false,
#    "isTypeExclusive": false,
#    "name": "DownloadedMoviesScan",
#    "trigger": "manual",
#    "suppressMessages": false
#  },
#  "priority": "normal",
#  "status": "started",
#  "queued": "2021-03-21T01:24:57.504838Z",
#  "started": "2021-03-21T01:24:58.6560938Z",
#  "trigger": "manual",
#  "state": "started",
#  "manual": true,
#  "startedOn": "2021-03-21T01:24:57.504838Z",
#  "stateChangeTime": "2021-03-21T01:24:58.6560938Z",
#  "sendUpdatesToClient": false,
#  "updateScheduledTask": true,
#  "id": 3266064
#}