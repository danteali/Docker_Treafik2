#!/bin/bash

## Script ot check IP addresses of running torrent containers


# If ipinfo.io commands don't work we can use our free account and API token to generate results:
# https://ipinfo.io/developers
# curl -u f3efd42d95a3f7: ipinfo.io
# curl -H "Authorization: Bearer f3efd42d95a3f7" ipinfo.io

red=$(tput setaf 1)
green=$(tput setaf 2)
#yellow=$(tput setaf 3)
#blue=$(tput setaf 4)
#magenta=$(tput setaf 5)
#cyan=$(tput setaf 6)
under=$(tput sgr 0 1)
reset=$(tput sgr0)
SOURCE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Function to get WAN IP address
function check_wan() { 
    # Check WAN IP/Country
    TMPFILE="$SOURCE/ipcheck_wan.txt"
    curl -s ipinfo.io > "$TMPFILE"
    ISPIP=$(grep -e \"ip "$TMPFILE" | tr -d '\n\r ,"ip:')
    ISPCO=$(grep -e country "$TMPFILE" | tr -d '", ' | sed 's/country://')
    rm "$TMPFILE"
    echo "ISP IP Address: ${green}$ISPIP${reset}"
    echo "ISP Country: ${green}$ISPCO${reset}"
    echo "" && echo "--------------------------------------" && echo
}

# Function to check container external IP addresses using curl
# If a container does not have curl available then we will need a different function
# And to define a separate array of container names to parse using that function.
function check_curl() { 
    TMPFILE="$SOURCE/${CONTAINER}_ipcheck.txt"
    if docker ps | grep "$CONTAINERNAME" | grep -q "Up"; then
        docker exec "$CONTAINERNAME" bash -c "curl -s ipinfo.io" > "$TMPFILE"
        IPADDRESS=$(grep -e \"ip "$TMPFILE" | tr -d '\n\r ,"ip:')
        IPCOUNTRY=$(grep -e country "$TMPFILE" | tr -d '", ' | sed 's/country://')
        rm "$TMPFILE"
        echo "$CONTAINERNAME IP Address: ${green}$IPADDRESS${reset}"
        echo "$CONTAINERNAME Country: ${green}$IPCOUNTRY${reset}"
        echo "" && echo "--------------------------------------" && echo
    else
        echo "${red}$CONTAINERNAME container not running${reset}"
        echo "" && echo "--------------------------------------" && echo
    fi
}


function check_wget() { 

    TMPFILE="$SOURCE/${CONTAINER}_ipcheck.txt"

    # IP returned with these commands
    #https://unix.stackexchange.com/questions/254328/get-the-external-ip-address-in-shell-without-dig-in-2016
    # wget -qqO- 'https://duckduckgo.com/?q=what+is+my+ip' | grep -ow 'Your IP address is [0-9.]*[0-9]' | grep -ow '[0-9][0-9.]*'
    # wget -qO- https://ipecho.net/plain
    # wget -qO- icanhazip.com
    # wget -qO- http://ipecho.net/plain | xargs echo

    # Countries returned in these responses but difficult to parse.
    #wget -qqO- 'https://duckduckgo.com/?q=what+is+my+ip' | grep -ow 'RO'
    #wget -qO- http://whatismycountry.com/
    #wget -qO- http://checkip.dyndns.org

    #if docker ps | grep "$CONTAINERNAME" | grep -q Up; then
    #    IPADDRESS=$(docker exec "$CONTAINERNAME" sh -c "wget -qO- icanhazip.com")
    #    echo "$CONTAINERNAME IP Address: ${green}$IPADDRESS${reset}"
    #    echo "$CONTAINERNAME Country: ${green}Can't easily obtain with wget :(${reset}"
    #    echo "" && echo "--------------------------------------" && echo
    #else
    #    echo "${red}$CONTAINERNAME container not running${reset}"
    #    echo "" && echo "--------------------------------------" && echo
    #fi

    if docker ps | grep "$CONTAINERNAME" | grep -q "Up"; then
        docker exec "$CONTAINERNAME" sh -c "wget -qO- ipinfo.io" > "$TMPFILE"
        IPADDRESS=$(grep -e \"ip "$TMPFILE" | tr -d '\n\r ,"ip:')
        IPCOUNTRY=$(grep -e country "$TMPFILE" | tr -d '", ' | sed 's/country://')
        rm "$TMPFILE"
        echo "$CONTAINERNAME IP Address: ${green}$IPADDRESS${reset}"
        echo "$CONTAINERNAME Country: ${green}$IPCOUNTRY${reset}"
        echo "" && echo "--------------------------------------" && echo
    else
        echo "${red}$CONTAINERNAME container not running${reset}"
        echo "" && echo "--------------------------------------" && echo
    fi

}

# Get current directory path
SOURCE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# List of containers check external IP addresses using curl
# If a container does not have curl available then we will need a different function
# And to define a separate array of container names to parse using that function.
CONTAINERLIST_CURL=(
    "vpn-torr"
    "deluge"
    "sonarr"
    "radarr"
    "prowlarr"
    "bazarr"
    "mylar"
    "deluge-exporter-prometheus"
    "varken"
    "transmission"
    "qbittorrent"
    "rutorrent"
    "jackett"
    "lazylibrarian"
  )

CONTAINERLIST_WGET=(
  "jdownloader"
  )

echo "${red}" && echo "================ ${under}Checking WAN IP${reset}${red} ==================="
echo "${reset}"

check_wan

echo "${red}" && echo "================ ${under}Checking ${#CONTAINERLIST_CURL[@]} containers with curl${reset}${red} ==================="
echo "${reset}"

for CONTAINERNAME in "${CONTAINERLIST_CURL[@]}"; do
   check_curl
done

echo "${red}" && echo "================ ${under}Checking ${#CONTAINERLIST_WGET[@]} containers with wget...${reset}${red} ==================="
echo "${reset}"

for CONTAINERNAME in "${CONTAINERLIST_WGET[@]}"; do
   check_wget
done

