#!/bin/bash

# shellcheck disable=SC2009


# If ipinfo.io commands don't work we can use our free account and API token to generate results:
# https://ipinfo.io/developers
# curl -u f3efd42d95a3f7: ipinfo.io
# curl -H "Authorization: Bearer f3efd42d95a3f7" ipinfo.io

#red=`tput setaf 1`
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
#under=`tput sgr 0 1`
reset=$(tput sgr0)
SOURCE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#SOURCE="/home/ryan/scripts/ip"

# LAN_IP=`ifconfig | grep -v Bcast:0.0.0.0 | grep -v 255.255.0.0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
#   | grep -v 255.255.0.0 - removes docker IPs, may unintentionally remove wanted IPs so check if not getting result expected.

# Better version than above based on interface name
# LAN_IP=$(ifconfig | grep -A1 'enp' | tail -1 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

# LAN_IP - better than above as it finds all physical interfaces
echo "${green}"
# Get list of physical interfaces
printf '%-18s \t %-15s \t %-17s\n' "Physical Interface" " IP Address" "MAC Address"
for i in $(find /sys/class/net -mindepth 1 -maxdepth 1 -lname '*virtual*' -prune -o -printf '%f\n' | grep -v 'bonding_masters'); do
	#echo "PHYSICAL INTERFACE: $i"
    ipAddress="$(ip -4 addr show "$i" | grep -e 'inet' | sed -r 's/^.*inet//g' | sed -r 's/\/.*//g')"
    if [[ -f "/sbin/ifconfig" ]]; then
        # ifconfig seems to be more reliable at returning MAC address, especially in WSL
        macAddress="$(/sbin/ifconfig "$i" | grep -o -E 'ether ([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')"
    else
        macAddress="$(ip addr show "$i" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | grep -v 'ff:ff:ff:ff:ff:ff')"
    fi
    printf '%-18s \t %-15s \t %-17s\n' "$i" "$ipAddress" "$macAddress"
done
echo 

# WAN IP & Country
curl -s ipinfo.io > "$SOURCE/ip.tmp"
ISP_IP=$(grep -e '"ip"' "$SOURCE/ip.tmp" | tr -d '\n\r ,"ip:')
ISP_CO=$(grep -e country "$SOURCE/ip.tmp" | tr -d '", ' | sed 's/country://')
rm "$SOURCE/ip.tmp"

# If local OpenVPN client running
if [ ! -f /usr/sbin/openvpn ]; then
    echo "${magenta}Local OpenVPN Client not installed - not checking for client IP${reset}"
    echo
else
    if ps -eo pid,etimes,etime,command | grep -e openvpn | grep -v -q "grep"; then
        VPN_IP=$(ifconfig | grep -A1 'tun' | tail -1 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')
        echo "${magenta}OpenVPN Client IP: $VPN_IP"
        echo
    else
        echo "${magenta}Local OpenVPN Client not running${reset}"
        echo    
    fi
fi

# WAN
echo "${cyan}WAN IP: $ISP_IP"
echo "External IP Country: $ISP_CO${reset}"
echo "${yellow}------------------------------------------------${reset}"
echo "Note: Plusnet static IP should be: 212.159.26.42"
echo "${yellow}------------------------------------------------${reset}"
echo

# WAN IP can be found by `curl`ing (or `wget -qO-`):
    # http://ifconfig.me
    # http://www.icanhazip.com
    # http://ipecho.net/plain
    # http://indent.me
    # http://bot.whatismyipaddress.com
    # https://diagnostic.opendns.com/myip
    # http://checkip.amazonaws.com
    # http://whatismyip.akamai.com
# Or with:
    # dig +short myip.opendns.com @resolver1.opendns.com
    # dig +short ANY whoami.akamai.net @ns1-1.akamaitech.net
    # dig +short ANY o-o.myaddr.l.google.com @ns1.google.com


# If docker torrent stack running
if docker ps | grep vpn | grep -q Up; then
  #docker run --rm --net=container:vpn-torr tutum/curl curl -s ipinfo.io > $SOURCE/torrent_ip.tmp
  #docker run --rm --net=container:vpn-torr curlimages/curl curl -s ipinfo.io > $SOURCE/torrent_ip.tmp
  docker exec vpn-torr bash -c "curl -s ipinfo.io" > "$SOURCE/torrent_ip.tmp"
  PIA_IP=$(grep -e '"ip"' "$SOURCE/torrent_ip.tmp" | tr -d '\n\r ,"ip:')
  PIA_CO=$(grep -e country "$SOURCE/torrent_ip.tmp" | tr -d '", ' | sed 's/country://')
  rm "$SOURCE/torrent_ip.tmp"
  echo "${blue}Docker VPN IP Address: $PIA_IP"
  echo "Docker VPN Country: $PIA_CO ${reset}" 
  echo
else
  echo "${blue}Docker VPN not running - no IP check performed${reset}"
  echo
fi
