#!/bin/bash

cd /home/ryan/scripts/docker || exit

echo "Set up macvlan for host to container communication"

/home/ryan/scripts/docker/scripts/macvlan/macvlan_docker.sh


echo "Restarting docker containers..."


# Changed to new 'docker compose' command as user aliases won't apply when run by root crontab
docker compose -f /home/ryan/scripts/docker/docker-compose.yml up -d --force-recreate

docker compose -f /home/ryan/scripts/docker/home-auto.yml up -d --force-recreate

#docker compose -f /home/ryan/scripts/docker/torrent.yml up -d --force-recreate
/home/ryan/scripts/docker/scripts/torrents/start_stack.sh

docker compose -f /home/ryan/scripts/docker/minecraft.yml up -d --force-recreate


# Start last after a pause since the container monitoring doesn't seem to like starting straight away
sleep 30
docker compose -f /home/ryan/scripts/docker/monitoring.yml up -d --force-recreate

# Sometimes docker creates services but doesn't start them - no idea why but let's start them just in case
# Only works if we're already in the /sripts/docker folder - see 'cd' above.
docker compose start