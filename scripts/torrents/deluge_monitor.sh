#!/bin/bash

## This script is added to crontab to regularly monitor whether delge connection is still behind a VPN, 
## and restart the stack if not.
## */05 * * * *        /home/ryan/scripts/docker/scripts/torrents/deluge_monitor.sh

## Also check for running deluge container with a GB IP address
## Kill deluge if it's IP is in GB.

blue=$(tput setaf 4)
red=$(tput setaf 1)
green=$(tput setaf 2)
#yellow=$(tput setaf 3)
#txtund=$(tput sgr 0 1)          # Underline
#txtbld=$(tput bold)             # Bold
reset=$(tput sgr0)

SOURCE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
STACKRESTART=("/home/ryan/scripts/docker/scripts/torrents/start_stack.sh")

TMPFILE="$SOURCE/deluge_monitor.ipcheck"

echo
# Check if deluge container running. Assume that if not running then monitor not needed.
if docker ps | grep -q "deluge"; then
  echo "${green}deluge container running - checking for completed torrents...${reset}" && echo

  #Check deluge container IP address. If not 'GB' then okay to be running. Otherwise kill.
  #docker run --rm --net=container:deluge appropriate/curl curl -s ipinfo.io > $SOURCE/deluge_ip.tmp
  docker exec deluge bash -c "curl -s ipinfo.io" > "$TMPFILE"
  IP=$(grep -e \"ip "$TMPFILE" | tr -d '\n\r ,"ip:')
  CO=$(grep -e country "$TMPFILE" | tr -d '", ' | sed 's/country://')
  echo "${blue}Deluge IP Address: $IP"
  echo "Deluge Country: $CO ${reset}" && echo
  rm "$TMPFILE"

  if [[ $CO != *"GB"* ]]; then
    echo "${green}Deluge IP not in GB - VPN connected${reset}"
    exit 0
  else
    echo "${red}Deluge IP in GB - VPN not connected - killing deluge container${reset}"
    docker stop deluge
    docker rm -f -v deluge
    #pushbullet "Deluge VPN disconnected - deluge stopped" "Disconnection noted at `date`. Killed deluge"
    #pushover -c "media_stack" -T "Deluge VPN disconnected - deluge stopped" -m "Disconnection noted at `date`. Killed deluge"
    #slack -u torrent_stack -c "#media_stack" -t "VPN NOT CONNECTED - KILLING TRANSMISSION" -e :arrow_double_down:

    pushover -c "media_stack" -T "Deluge VPN disconnected - killed deluge & triggering stack restart" -m "Disconnection noted at $(date). Killed deluge & stack restart triggered"
    slack -u torrent_stack -c "#media_stack" -t "VPN NOT CONNECTED - KILLING DELUGE & RESTARTING STACK" -e :arrow_double_down:

    # Restart stack
    "${STACKRESTART[@]}"

    # Also remove transmisson monitor for Grafana stats
    #docker rm -f -v prometheus-deluge > /dev/null 2>&1
    
    exit 1
  fi

else
  echo "${blue}deluge container not running${reset}" && echo
  exit 0
fi
