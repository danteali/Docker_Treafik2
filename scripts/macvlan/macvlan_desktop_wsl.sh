#!/bin/bash

# For: Windows Desktop - WSL

# This runs at server startup (via crontab) to allow containers to be assigned IP addresses on the LAN
# and allow the docker host to communicate with these containers just like any other LAN machine.

# VARIABLES
ROUTER="192.168.0.1"    # Don't change this unless router changes address
# Change these for the specific docker host and LAN address space to be used
DOCKERHOST="192.168.0.20/32"    # Include the '/32'
INTERFACE="eth0"
MACVLANADDRESSES="192.168.0.232/29"

# DELETE OLD MACVLAN JUST IN CASE IT IS STILL THERE 
sudo ip link delete lan_net-shim

# CHECK THAT NETWORK CONNECTION IS UP
while ! ping -q -c 1 192.168.0.1 > /dev/null
do
    echo "$0: Cannot ping router, waiting another 5 secs..."
    sleep 5
done

# CONFIGURE MACVLAN 'NETWORK'
sudo ip link add lan_net-shim link $INTERFACE type macvlan mode bridge
sudo ip addr add $DOCKERHOST dev lan_net-shim
sudo ip link set lan_net-shim up

# ALLOW HOST <-> MACVLAN CONTAINER NETWORKING
sudo ip route add $MACVLANADDRESSES dev lan_net-shim

