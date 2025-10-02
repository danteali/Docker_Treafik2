#!/bin/bash

# Check running as root - attempt to restart with sudo if not already running with root
if [ "$(id -u)" -ne 0 ]; then echo "$(tput setaf 1)Not running as root, attempting to automatically restart script with root access...$(tput sgr0)"; echo; sudo "$0" "$@"; exit 1; fi

cd "/home/ryan/scripts/docker/other-docker-host-configs/minecraft" || exit

mkdir -p crontabs
#ssh -i /home/ryan/.ssh/infrastructure monitoring crontab -l > "crontabs/user.crontab"
sudo ssh -i /home/ryan/.ssh/infrastructure minecraft sudo crontab -l > "crontabs/root.crontab"

mkdir -p scripts-docker
sudo scp -r minecraft:/root/scripts/docker/* scripts-docker/

mkdir -p system-files/etc/pelican
sudo scp -r minecraft:/etc/pelican/* system-files/etc/pelican/

# # There are no docker services with data saved in /storage/Docker
# 
# mkdir -p docker-app-data
# mkdir -p docker-app-data/grafana/data
# scp -r monitoring:/storage/Docker/grafana/data/provisioning docker-app-data/grafana/data/
# 
# mkdir -p docker-app-data
# scp -r monitoring:/storage/Docker/snmp-exporter docker-app-data/

