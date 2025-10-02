#!/bin/bash

# Check running as root - attempt to restart with sudo if not already running with root
if [ "$(id -u)" -ne 0 ]; then echo "$(tput setaf 1)Not running as root, attempting to automatically restart script with root access...$(tput sgr0)"; echo; sudo "$0" "$@"; exit 1; fi

cd "/home/ryan/scripts/docker/other-docker-host-configs/pi-backup" || exit

mkdir -p scripts-docker
sudo scp -r pi-backup-ts:/home/pi/scripts/docker/* scripts-docker/

mkdir -p docker-app-data
sudo scp -r pi-backup-ts:/storage/Docker/* docker-app-data/

mkdir -p crontabs
sudo ssh -i /home/ryan/.ssh/infrastructure pi-backup-ts crontab -l > "crontabs/user.crontab"
sudo ssh -i /home/ryan/.ssh/infrastructure pi-backup-ts sudo crontab -l > "crontabs/root.crontab"
