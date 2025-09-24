#!/bin/bash

# Running the service via docker compose works but it doesn't recognise the env var to set the 
# schedule for running the Kometa jobs. And doesn't recognise the command line argument.
# When run with docker compose, the Plex libray analysis/updates runs persistently in a loop and
# doesn't wait for the scheduled start. 

# Have scheduled this script in crontab to run daily at 10:30 (although timing may change in future, 
# and this note may not be updated with latest crontab execution time).

docker run -d --rm \
  --name plex-kometa \
  --network t2_proxy \
  -v "/var/log/docker/kometa:/config/logs:rw" \
  -v "/storage/Docker/kometa/data/config:/config:rw" \
  -v "/storage/Docker/kometa/data/assets:/assets:rw" \
  kometateam/kometa \
    --run --run-libraries "Movies|TV Shows|UFC"

