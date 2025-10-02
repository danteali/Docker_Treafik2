#!/bin/bash
#shellcheck disable=SC2199,SC2124

#red=$(tput setaf 1)
#green=$(tput setaf 2)
#yellow=$(tput setaf 3)
#magenta=$(tput setaf 5)
#under=$(tput sgr 0 1)
cyan=$(tput setaf 6)
blue=$(tput setaf 4)
reset=$(tput sgr0)

# BRING UP FULL SET OF SERVICES IN MAIN COMPOSE FILE
    COMPOSE_FILE=/home/ryan/scripts/docker/minecraft.yml
    docker compose -f $COMPOSE_FILE up -d --force-recreate

# Target compose file can be defined in script or passed as 1st arguement.
# Should be full path.

# Specific services within compose file can be defined in script, or
# passed as arguments following compose specification.

# Potential implrovements:
# - Validataion e.g.
#    - does compose file exist
#    - do services exist in specified compose

# BRING UP ONLY SUBSET OF SERVICES IN EXTRA FILE
COMPOSE_FILE=/home/ryan/scripts/docker/minecraft_extra.yml
SERVICES='mc-fabric-Hermitcraft7'
          #telegraf-listener-minecraft


if [[ $@ ]]; then
    COMPOSE_FILE=$1
    SERVICES=${@:2}
fi

echo

if [ -z "$SERVICES" ]; then
    echo "${cyan}No services specified, (re-)starting whole compose file:${reset}"
    echo "${blue}    $COMPOSE_FILE${reset}"
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate
else
    echo "${cyan}(re-)starting specified services from:${reset}"
    echo "${blue}    $COMPOSE_FILE${reset}"
    echo

    #echo "Setting up service array"
    read -r -a service_array <<<"$SERVICES"

    for i in "${service_array[@]}"; do
        echo "${cyan}(re-)starting service - ${blue}$i${reset}";
        docker compose -f "$COMPOSE_FILE" up -d --force-recreate "$i"
    done

fi

echo
