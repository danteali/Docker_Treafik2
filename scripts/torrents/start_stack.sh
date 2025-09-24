#!/bin/bash

# shellcheck disable=SC2294

# If ipinfo.io commands don't work we can use our free account and API token to generate results:
# https://ipinfo.io/developers
# curl -u f3efd42d95a3f7: ipinfo.io
# curl -H "Authorization: Bearer f3efd42d95a3f7" ipinfo.io

# Assign 'virtual' terminal if runnning without a terminal connected (e.g. Webmin, SSH)
# Avoids error: tput: No value for $TERM and no -T specified
if ! tty -s; then TERM=xterm; fi

#blue=$(tput setaf 4)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
txtund=$(tput sgr 0 1)          # Underline
reset=$(tput sgr0)

WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
NOTIFYHELPER="/home/ryan/scripts/notification-helper/notify.sh"
COMPOSEFILE="/home/ryan/scripts/docker/torrent.yml"
IPCHECKLOG="$WHEREAMI/start_stack.txt"
VPNCONNECTED=0
VPNCOUNTMAX=10

ISPIP="$(curl -s ipinfo.io | grep -e \"ip | tr -d '\n\r ,"ip:')"
ISPCO="$(curl -s ipinfo.io | grep  -e country | tr -d '", ' | sed 's/country://')"

function main(){

    # Confirm yq installed to parse compose yaml
    if command -v yq >/dev/null; then
        echo "yq installed, continuing"
    else
        echo "yq command required, install with apt or snap"
        exit 1
    fi

    # Stop any currently running torrent containers
    stop

    # Start services
    docker compose -f "$COMPOSEFILE" up -d --force-recreate

    # Check for VPN connection
    while [[ $VPNCONNECTED == 0 ]]
    do
      #docker run --rm --net=container:vpn-torr appropriate/curl curl -s ipinfo.io > $IPCHECK
      docker exec vpn-torr bash -c "curl -s ipinfo.io" > "$IPCHECKLOG"
      VPNIP=$(grep "$IPCHECKLOG" -e \"ip | tr -d '\n\r ,"ip:')
      VPNCO=$(grep "$IPCHECKLOG" -e country | tr -d '", ' | sed 's/country://')
      rm "$IPCHECKLOG"

      echo "ISP IP (Country): $ISPIP ($ISPCO)"
      echo "VPN IP (Country): $VPNIP ($VPNCO)"

      #if [[ $VPNCO == *"ES"* ]] || [[ $VPNCO == *"RO"* ]] || [[ $VPNCO == *"TR"* ]] || [[ $VPNCO == *"BR"* ]] || [[ $VPNCO == *"NO"* ]] || [[ $VPNCO == *"BG"* ]]; then
      if [[ "$VPNCO" != "" ]] && [[ "$VPNCO" != *"GB"* ]]; then
        VPNCONNECTED=1
        echo "${green}VPN Connected!${reset}"; echo
      else
        VPNCOUNT=$((VPNCOUNT+1))
        echo "${red}(Check $VPNCOUNT of $VPNCOUNTMAX) VPN Not Connected${reset}"
        echo "----------------------------"
        sleep 5
      fi

      if [[ $VPNCOUNT == "$VPNCOUNTMAX" ]]; then
        echo "${red}Max Connection Attempts Reached - Killing Services...${reset}"
        # Stop containers
        stop
        exit 1
      fi
    done

    # DON'T DO IT THIS WAY SINCE EACH SERVICE STARTED WILL RESTART VPN
    ## Start remaining services
    #while read -r container; do
    #  if [[ "$container" != "vpn"* ]]; then
    #      docker compose -f "$COMPOSEFILE" up -d --force-recreate "$container"
    #  fi
    #done <<< "$(yq -r .services[].container_name "$COMPOSEFILE")"

    # Notify re-start
    notify

}

function stop(){
    echo "${red}" && echo "================ ${txtund}Stopping any torrent containers${reset}${red} ==================="
    echo "${reset}"

    docker compose -f $COMPOSEFILE down
    docker compose rm -f -v

    #echo ${yellow}
    #docker stop \
    #    vpn-torr \
    #    transmission \
    #    sonarr \
    #    radarr \
    #    jackett \
    #    prowlarr \
    #    mylar \
    #    bazarr \
    #    lazylibrarian
    #
    #echo ${blue}
    #docker rm -f -v \
    #    vpn-torr \
    #    transmission \
    #    sonarr \
    #    radarr \
    #    jackett \
    #    prowlarr \
    #    mylar \
    #    bazarr \
    #    lazylibrarian
    
    echo "${reset}"
}


# SEND EMAIL #
function notify(){
    echo "${green}"
    echo "===================== sending notifications ===================="
    echo "${yellow}"
    #pushbullet "Torrent Services Started" "`date`"
    #pushover -c "media_stack" -T "Torrent Services Started" -m "$(date)"
    #slack -u torrent_stack -c "#media_stack" -t "Torrent Stack (Re)Started" -e :arrow_double_down:

    unset NOTIFYCMD; 
    NOTIFYCMD=("$NOTIFYHELPER")
    NOTIFYCMD+=("--services 'pb,slack,discord'")
    NOTIFYCMD+=("--title 'Torrent Services Started'")
    NOTIFYCMD+=("--msg \"Torrent Stack Started at $(date)\"")
    NOTIFYCMD+=("--channel 'media_stack'")
    NOTIFYCMD+=("--colour 'green'")
    NOTIFYCMD+=("--slackemoji ':arrow_double_down:'")
    echo "Running: ${NOTIFYCMD[*]}" 
    eval "${NOTIFYCMD[@]}"

    echo "${reset}"
}

main "$@"
