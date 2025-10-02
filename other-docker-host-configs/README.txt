These files are copied from other machines on our network which run docker services. 

COPYING FILES
• Use the 'copy-docker-host-files.sh' script to pull the latest updates from the other systems. 

• View full script usage details with: 
    copy-docker-host-files.sh --help
  
• In general we run the command with the remote hostname supplied as an argument.
    copy-docker-host-files.sh --remote-host=pihole
        - the remote host must have an entry in the /etc/ssh/ssh_config file to authenticate SSH
        - the remote hostname must have a corresponding folder in the same directory as the script.

ANSIBLE TASKS
• Common services are deployed to our other systems using Ansible to create docker compose files:
    - ansible-core-services.yml
        - socket-proxy
        - portainer
        - portainer-agent
        - watchtower
        - dem (docker event monitor)
    - ansible-cadvisor.yml
        - cadvisor

• Ansible will add variables to the .env file for any sensitive info in the compose files. 

• Ansible will insert relevant content at the start of the .env file (and update it if the source 
  Ansible template is updated) - it will not overwrite or remove any .env content so the file can
  still be used for other docker services too.

Optionally, a macvlan script can be configured on the remote host  ansible using subnet values defined in the
ansible role's defaults/main.yaml file.

Each host will also likely have it's own set of docker services
    - See scripts-docker directory for compose files.
And corresponding Docker data files, e.g. config files.
    - See storage-docker folder for container data.
