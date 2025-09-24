# Docker Stack
This is my Docker stack on my main server, using Trefik v3 as a reverse proxy and PiHole to resolve DNS for our services so that the FQDNs work internally.
(This repo is named due to Traefik having a major update going from v1 to v2 so we re-factored our docker stack at that point).

There are some additional services running in virtual machines but those files have not (yet) been included here.

## Other Notes (may be outdated)

#### External Access
Use cloudflared to avoid opneing firewall ports. 

#### Internal Access
Use Traefik reverse proxy.
We can keep all traffic local if we configure DNS resolution to point any LAN devices at our server's IP. We can do this using one of these methods (hint: use #3!):
1. Edit the 'hosts' file on each LAN machine (use Google to find out how to do this as it changes depending on your operating system) so that the machine resolves the URL to the IP of your server. This is really annoying to maintain as each machine needs to have the hosts file updated. 
2. If your router provides DNS for your LAN you can probably edit the hosts file on the router to resolve services centrally. If you are using your router as a DNS server you likely already have a good idea how to configure it to resolve to your proxied addresses, if not then Google it!
3. Use pihole! [the docker compose snippet is in this repo) 

Pihole's main job is an ad blocker for your network. It operates as a local DNS server and blocks common advertising sites. Following pihole config guides (Google it) we end up with all our LAN devices pointing at the pihole for DNS resolution (the DNS nameservers are generally handed out to our devices via DHCP as configured in our router). We can use this to our advantage and edit its hosts file to resolve our proxied URLs. 

#### Unexposed services and HTTPS access
Our service URLs only receive an SSL certificate if they can be reached externally since Let's Encrypt needs to perform it's challenge/response to verify that we own the URL before issuing a certificate. However there is a mechanism to generate a wildcard certificate for our domain (e.g. `*.yourdomain.com`) and configure Traefik to use this for any URLs which do not get their own specifically generated certificate (see traefik.toml [entryPoints.https] section). I followed the guide [here](https://blog.thesparktree.com/generating-intranet-and-private-network-ssl) and used the generated certs in the traefik.toml [entryPoints.https] section. 

### Containers with their own LAN IP
A couple of the containers I use become more useful if they have their own IP address on the LAN (home-assistant, node-red). While not absolutely neccessary I found it useful as it enabled integration with some services to work better (e.g. alexa integration).
To give a docker container its own IP address on the LAN, first we need to create a network interface on the host machine for it. The purpose of this is to allow the host machine to communicate with the container since, by default for security reasons, if a container has it's own LAN IP the host machine is blocked from communicating directly with it. 

You can call the interface whatever you want, but I’m calling this one lan_net-shim:
`sudo ip link add lan_net-shim link enp4s0 type macvlan  mode bridge`

Now we need to configure the interface with our host's own LAN IP address and bring it up:
```
sudo ip addr add 192.168.0.10/32 dev lan_net-shim
sudo ip link set lan_net-shim up
```

Now we need to tell our host to use that interface when communicating with the containers. Decide what IP range you want to reserve for the containers and use it in the following command. For example here we have reserved `192.168.0.224/29` which gives the containers .225 to .231 to use (we don't use the first IP .224 as it's reserved for host <-> container network communication).
`sudo ip route add 192.168.0.224/29 dev lan_net-shim`

We put these commands in a script [here](https://github.com/danteali/DockerRunFiles/blob/master/macvlan/macvlan_docker.cleaned) to be run at host startup by crontab. Just make sure it properly reflects your own IP addresses and ethernet interface. 
Then we need to create a docker network for any containers which get their own IP. Make sure to use the same IP addresses/ranges as used in the host interface above, and also the correct ethernet interface name of your host (get with `ifconfig`): 
```
docker network create \
  -d macvlan \
  --subnet=192.168.0.0/24 \
  --gateway=192.168.0.1 \
  --ip-range=192.168.0.224/29 \
  -o parent=enp4s0 \
  lan_net
```

Then when starting a container use these options to give it it's own IP on the LAN:
```
--network lan_net \
--ip=192.168.0.225 \
```
Also see guide [here](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/) which helped me.



### aliases
You can make command line interaction with docker a bit easier by adding these aliases to the `.bash_aliases` file in your home directory. You can type these aliases instead of the longer docker commands. You might need to install the JSON parser `jq` as some of these aliases use it to parse/prettify docker json output. Note that one of the aliases is `daliases` which will list all of the other aliases just in case you forget what they are!

Once you update `.bash_aliases` run `source ~/.bash_aliases` to make them work. e.g. type `dps` to list all docker containers running.

```bash
########################
######## DOCKER ########
########################

##list containers
alias dps='docker ps'
##list containers & grep to find string
alias dpsg='docker ps | grep'
##list ALL containers incl stopped
alias dpsa='docker ps -a'
##remove (running) container
alias drm='docker rm -f -v'
##get container ID
alias did='docker inspect --format="{{.Id}}"'
##Get container IP
alias dip='docker inspect --format="{{ .NetworkSettings.IPAddress }}" "$@"'
## Get docker PID
alias dpid='docker inspect --format="{{ .State.Pid }}" "$@"'
##View container logs
alias dlog='docker logs -f'
##list images
alias dim='docker images'

### CLEANUP ###
## remove dangling images
alias drm_i=' docker rmi $(docker images --filter dangling=true -q)' #test comment
##remove stopped containers
alias drm_c='docker rm -v $(docker ps --filter status=exited -q)'
##remove dangling volumes
alias drm_v='docker volume rm $(docker volume ls -f dangling=true -q)'
##prune unused networks
alias drm_net='docker network prune'
##do all cleanup functions above
d_cleanup() { $(drm_i); $(drm_c); $(drm_v); $(drm_net); }

### FUNCTIONS ###
## List container IP address
#dip() { docker inspect -f '{{ json .NetworkSettings.IPAddress }}' $(did $@) | python -mjson.tool ; }
## List container network info
dnet() { docker inspect -f '{{ json .NetworkSettings }}' $(did $@) | python -mjson.tool | jq ; }
## Start sh shell in container
dsh() { docker exec -i -t $@ /bin/sh ; }
## Start bash shell in container
dbash() { docker exec -i -t $@ /bin/bash ; }

##list docker aliases
dalias () {
  tput setaf 6
  echo
  cat ~/.bash_aliases | grep -e 'docker' | grep -e 'alias' | grep -v '##' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/"| sed "s/['|\']//g" | sort | sed -r 's/^alias //'
  cat ~/.bash_aliases | grep -e 'docker' | grep -e '() { .* }' | grep -v '##' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/"| sed "s/['|\']//g" | sort | sed -r 's/^alias //'
  tput sgr 0
  echo
}
```



### Misc Notes

* There is a montoring script [here](https://github.com/danteali/Docker_Treafik2/blob/master/scripts/monitoring/crontab_monitor/crontab_monitor.sh) which can be added to crontab to monitor docker containers in case they go down. A different version with clearer comments is available in my [other repo here](https://github.com/danteali/docker_cron_monitor). You should probably use the one from the other repo as the one in this repo has had some additional customisation and is probably no longer as easy to understand. 

