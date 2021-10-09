#!/bin/bash

blue=`tput setaf 4`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
txtund=`tput sgr 0 1`          # Underline
reset=`tput sgr0`

WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
COMPOSE_FILE=/home/ryan/docker/torrent.yml
IPCHECKLOG="$WHEREAMI/ipcheck_vpn.log"
ISPIP=`curl -s ipinfo.io | grep -e ip | tr -d '\n\r ,"ip:'`
VPNCONNECTED=0



function main(){

    # Stop any currently running containers
    stop


    # Start stack
    docker-compose -f $COMPOSE_FILE up -d


    # Check for VPN connection
    while [[ $VPNCONNECTED == 0 ]]
    do
      docker run --rm --net=container:vpn-torr appropriate/curl curl -s ipinfo.io > $IPCHECK
      PIAIP=`cat $IPCHECK | grep -e \"ip | tr -d '\n\r ,"ip:'`
      PIACO=`cat $IPCHECK | grep -e country | tr -d '", ' | sed 's/country://'`

      if [[ $PIACO == *"ES"* ]] || [[ $PIACO == *"RO"* ]] || [[ $PIACO == *"TR"* ]] || [[ $PIACO == *"BR"* ]] || [[ $PIACO == *"NO"* ]]; then
        VPNCONNECTED=1
        echo ${green}
        echo "VPN Connected on IP: $PIAIP"
        echo "VPN Country: $PIACO"
        echo "Continuing with service startup...${reset}"
      else
        VPNCOUNT=$((VPNCOUNT+1))
        echo "${reset}# of VPN checks: $VPNCOUNT"
        echo "PIA IP Address: $PIAIP"
        echo "PIA Country: $PIACO"
        echo "----------------------------"
        sleep 5
      fi

      if [[ $VPNCOUNT == 10 ]]; then
        echo "${red}VPN not connected, exiting startup script."
        echo "Killing containers...${reset}"
        # Stop containers
        stop
        exit 1
      fi
    done

    # Notify re-start
    notify

}

function stop(){
    echo ${red} && echo "================ ${txtund}Stopping any torrent containers${reset}${red} ==================="
    echo ${reset}

    docker-compose -f $COMPOSE_FILE down

    #echo ${yellow}
    #docker stop \
    #    vpn-torr \
    #    transmission \
    #    sonarr \
    #    radarr \
    #    jackett \
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
    #    bazarr \
    #    lazylibrarian
    
    echo ${reset}
}


# SEND EMAIL #
function notify(){
    echo ${green}
    echo "===================== sending notifications ===================="
    echo ${yellow}
    #pushbullet "Torrent Services Started" "`date`"
    pushover -c "media_stack" -T "Torrent Services Started" -m "`date`"
    slack -u torrent_stack -c "#media_stack" -t "Torrent Stack (Re)Started" -e :arrow_double_down:
    echo ${reset}
}

main "$@"