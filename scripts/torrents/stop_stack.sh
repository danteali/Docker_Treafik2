#!/bin/bash

#blue=`tput setaf 4`
red=$(tput setaf 1)
#green=`tput setaf 2`
yellow=$(tput setaf 3)
txtund=$(tput sgr 0 1)          # Underline
reset=$(tput sgr0)

COMPOSE_FILE=/home/ryan/scripts/docker/torrent.yml

echo "${red}" && echo "================ ${txtund}Stopping any torrent containers${reset}${red} ===================${reset}"
echo "${yellow}"

docker compose -f $COMPOSE_FILE down
docker compose rm -f -v

#echo "${yellow}"
#docker stop \
#    vpn-torr \
#    transmission \
#    deluge \
#    qbittorrent \
#    sonarr \
#    radarr \
#    jackett \
#    prowlarr \
#    mylar \
#    bazarr \
#    jdownloader \
#    lazylibrarian \
#    rutorrent
#  
#echo "${blue}"
#docker rm -f -v \
#    vpn-torr \
#    transmission \
#    deluge \
#    qbittorrent \
#    sonarr \
#    radarr \
#    jackett \
#    prowlarr \
#    mylar \
#    bazarr \
#    jdownloader \
#    lazylibrarian \
#    rutorrent

echo "${reset}"

