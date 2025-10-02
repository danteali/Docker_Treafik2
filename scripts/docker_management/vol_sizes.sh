#!/bin/bash

# Add container name as arguement to assess only one container

# And output summary of all log files.

# ======================================================================
# May need to do this to get proper log file output
# Otherwise not certain we can properly run: sudo du -c -d 1 -h /var/lib/docker/containers/5638557a547aca22ed49009c25139579a5720bbfcedf0498e31cc131927ec739/*.log
# Apply to: /var/lib/docker/containers/<container long ID>
# Or to all: /var/lib/docker/containers
# sudo setfacl -Rm u:ryan:rwx $@ ; sudo setfacl -Rdm u:ryan:rwx $@ ;
# ======================================================================

    red=`tput setaf 1`
    green=`tput setaf 2`
    yellow=`tput setaf 3`
    blue=`tput setaf 4`
    magenta=`tput setaf 5`
    cyan=`tput setaf 6`
    under=`tput sgr 0 1`
    reset=`tput sgr0`



# Check running as root - attempt to restart with sudo if not already running with root
    if [ $(id -u) -ne 0 ]; then tput setaf 1; echo "Not running as root, attempting to automatically restart script with root access..."; tput sgr0; echo; sudo $0 $*; exit 1; fi

   
# Analyse docker volumes etc
# Details of various commands used below:
#   tr ' ' '\n' = split into separate lines using ' ' as delimiter
#   sed '/bind\|true.../d' = delete lines containing these strings (can add more)
#   sed 's/\:ro\|:rw//g' = delete these strings from output (can add more)
#   sed '/^$/d' = delete empty lines
#   sed -n '0~2!p' = keep every 2nd line
#   sed 's/^/    /' = adds spaces in front of command output (indenting)
#   sed 's/^.....//' = remove leading characters (replace with . which equals nothing)
#   sed 's|[,) ]||g' = remove all chars between [ ]
#   sed 's/}//' = remove character '}'
#   tr -d [ = delete '[' character
#   d_image=${d_image_raw:8:12} = get 12 characters from string starting at position 8 (count from at 0)
#   numfmt --from=iec = convert from human readable to bytes
#   numfmt --to=iec = convert from bytes to human readable
#   ${d_image_size^^} = convert to uppercase
#   ${d_image_size,,} = convert to lowercase
#   tr '[:lower:]' '[:upper:]' = make lowercase chars into upper
#   tr '[:upper:]' '[:lower:]' = make uppercase chars into lower



################################################################################################################################
###### INDIVIDUAL CONTAINER METRICS
################################################################################################################################

# ZERO VARIABLES TO HOLD TOTALS FOR METRICS BELOW
d_container_size_b_total=0
d_container_size_virtual_b_total=0
d_image_size_b_total=0
d_image_size_shared_b_total=0
d_image_size_unique_b_total=0


echo ""
echo "${cyan}=================================================================================================================="

#d_id_short="64080f94a1b2"

# For use if setting up file to take a container name as argument
#if [[ -z $1 ]]; then
#    d_name=$1
#    d_id_short=`docker inspect -f {{.Name}} $d_name | head -c 12`
#fi

for d_id_short in `docker ps -a -q`; do

    # Check if container name passed into script and reset d_id_short to match 
    # script exists after one loop in this case
    if [[ $1 != "" ]]; then
        d_id_short=$(docker ps | grep "$1" | awk '{print $1}')
    fi


    d_id=$(docker inspect -f {{.Id}} $d_id_short )

    d_name=$(docker inspect -f {{.Name}} $d_id_short | sed 's/^.//' )
    
    d_logpath=$(docker inspect -f {{.LogPath}} $d_id_short )

    echo ""
    echo "CONTAINER: ${green}$d_name ${cyan}(${green}$d_id_short${cyan})"
    echo ""
    echo "------------------------------------------------------------------------------------------------------------------"
    echo ""
    echo "${magenta}CONTAINER FOLDER SIZE ${magenta}(${green}$d_name${magenta})"
    echo "${magenta}[/var/lib/docker/containers/<CONTAINER_ID>]"
    echo ""
    
    
    # Get sizes of all container dirs then grep for our one
        #sudo du -c -d 2 -h /var/lib/docker/containers | \
        #    grep `docker inspect -f "{{.Id}}" $d_id_short` | \
        #    sed 's/^/    /'
    
    # Better way instead is to use our container ID in the command to get only it's info
    sudo du -c -d 1 -h /var/lib/docker/containers/$d_id | \
        sed 's/^/\t/'
    

    #------------------------------------------------------------------------

    echo ""
    echo "${yellow}LOGFILE SIZES (${green}$d_name${yellow})"
    echo "[also included in docker-managed storage above]"
    echo ""

    sudo du -c -d 1 -h /var/lib/docker/containers/$d_id/*.log | \
        sed 's/^/\t/'
    



    #------------------------------------------------------------------------



    echo ""
    echo "${red}CONTAINER SIZE (${green}$d_name${red})"
    echo "${red}[docker ps --size | grep <CONTAINER_ID_SHORT>]"
    echo "${red}[docker system df -v | grep <CONTAINER_ID_SHORT>]"
    echo ""
  
    # Could use this command but it doesn't give the 'virtual' size
    # docker system df -v | grep "$d_id_short"
    
    d_container_size_raw=$(docker ps --size --filter id="$d_id_short"  --format "{{.Size}}")
        #64.6MB (virtual 372MB)
    d_container_size=$(echo $d_container_size_raw | awk '{print $1}' )
        #64.6MB
    d_container_size_virtual=$(echo $d_container_size_raw | awk '{print $3}' | sed 's/)//' )
        #372MB

    printf "\t%-10s %-35s %12s\n" "SIZE" "" ""
    printf "\t%-10s %-35s %12s\n" "$d_container_size" "Container Size" ""
    printf "\t%-10s %-35s %12s\n" "$d_container_size_virtual" "Container Size (Virtual)" ""



    # Want to sum totals while looping through containers, to process above size output ...
    #   - Sizes are human readable with ending strings GB,MB,kB,B - but need only G,M,K (upper case) or no char if already in bytes
    #   - Need to remove 'B' to get into correct format for conversion
    #   - Need to ensure remaining character is in upper case to get into correct format for conversion
    # After summing, convert back to human readable with: | numfmt --to=iec

    # Convert size to bytes for total summing
       
    d_container_size_b=$( echo $d_container_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
    
    
    d_container_size_b_total=$(($d_container_size_b_total + $d_container_size_b))



    # Convert virtual size to bytes for total summing
        
    d_container_size_virtual_b=$( echo $d_container_size_virtual | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )    

    d_container_size_virtual_b_total=$(($d_container_size_virtual_b_total + $d_container_size_virtual_b))


    #------------------------------------------------------------------------


    echo ""
    echo "${blue}CONTAINER OVERLAY FOLDER SIZE (${green}$d_name${blue})"
    echo "${blue}[docker inspect -f {{.GraphDriver.Data}} <CONTAINER_ID_SHORT>]"
    echo ""
  
    echo "LowerDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} $d_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "MergedDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker inspect -f {{.GraphDriver.Data.MergedDir}} $d_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "UpperDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker inspect -f {{.GraphDriver.Data.UpperDir}} $d_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "WorkDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker inspect -f {{.GraphDriver.Data.WorkDir}} $d_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    #------------------------------------------------------------------------

    echo "${cyan}------------------------------------------------------------------------"
    echo "IMAGE INFO"
    echo "------------------------------------------------------------------------"
    echo ""
    
    echo "${magenta}IMAGE SIZE (${green}$d_name${magenta})"
    echo "${magenta}[docker system df -v | grep <IMAGE_ID_SHORT>]"
    echo ""

    d_image_id_raw=$(docker inspect -f {{.Image}} $d_id_short)
        #sha256:040acfe07efced14a30c3992ff559b883c6920800b2f291f7f28650d3857860d

    d_image_id_short=${d_image_id_raw:7:12}
        #040acfe07efc

    d_image_size_raw=$(docker system df -v | grep "$d_image_id_short")
        #REPOSITORY                              TAG         IMAGE ID       CREATED         SIZE      SHARED SIZE   UNIQUE SIZE   CONTAINERS
        #lscr.io/linuxserver/radarr              latest      040acfe07efc   3 weeks ago     307.9MB   0B            307.9MB       1

    d_image_size=$(echo $d_image_size_raw | awk '{print $(NF-3)}' )
        #307.9MB
    d_image_size_shared=$(echo $d_image_size_raw | awk '{print $(NF-2)}' )
        #0B
    d_image_size_unique=$(echo $d_image_size_raw | awk '{print $(NF-1)}' )
        #307.9MB
    d_image_containers=$(echo $d_image_size_raw | awk '{print $(NF-0)}' )
        #1
    

    printf "\t%-10s %-35s %12s\n" "SIZE" "" ""
    printf "\t%-10s %-35s %12s\n" "$d_image_size" "Image Size" ""
    printf "\t%-10s %-35s %12s\n" "$d_image_size_shared" "Image Size - Shared" ""
    printf "\t%-10s %-35s %12s\n" "$d_image_size_unique" "Image Size - Unique" ""
    echo
    printf "\t%-10s %-35s %12s\n" "$d_image_containers" "# of containers using image" ""



    # Want to sum totals while looping through containers, to process above size output ...
    #   - Sizes are human readable with ending strings GB,MB,kB,B - but need only G,M,K (upper case) or no char if already in bytes
    #   - Need to remove 'B' to get into correct format for conversion
    #   - Need to ensure remaining character is in upper case to get into correct format for conversion
    # After summing, convert back to human readable with: | numfmt --to=iec

    # Convert size to bytes for total summing
       
    d_image_size_b=$( echo $d_image_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
    
    
    d_image_size_b_total=$(($d_image_size_b_total + $d_image_size_b))



    # Convert shared size to bytes for total summing
        
    d_image_size_shared_b=$( echo $d_image_size_shared | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )    

    d_image_size_shared_b_total=$(($d_image_size_shared_b_total + $d_image_size_shared_b))


    # Convert unique size to bytes for total summing
        
    d_image_size_unique_b=$( echo $d_image_size_unique | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )    

    d_image_size_unique_b_total=$(($d_image_size_unique_b_total + $d_image_size_unique_b))


    #------------------------------------------------------------------------


    echo ""
    echo "${yellow}IMAGE OVERLAY FOLDER SIZE (${green}$d_name${yellow})"
    echo "${yellow}[docker image inspect -f {{.GraphDriver.Data}} <IMAGE_ID_SHORT>]"
    echo ""
  
    echo "LowerDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker image inspect -f {{.GraphDriver.Data.LowerDir}} $d_image_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "MergedDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker image inspect -f {{.GraphDriver.Data.MergedDir}} $d_image_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        echo $temp
        if [[ $temp != "" ]]; then
            temp_size=$(echo $temp | awk '{print $1}')
            temp_loc=$(echo $temp | awk '{print $2}')
            printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

            temp_size_b=$( echo $temp_size | \
                                    sed 's/[bB]//g' | \
                                    tr '[:lower:]' '[:upper:]' | \
                                    numfmt --from=iec )
            temp_size_b_total=$(($temp_size_b_total + $temp_size_b))
        fi

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "UpperDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker image inspect -f {{.GraphDriver.Data.UpperDir}} $d_image_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    echo "WorkDir"
    #for i in $(echo $(docker inspect -f {{.GraphDriver.Data.LowerDir}} fbcce8438cfa) | tr ":" "\n" | sed 's/^/\t/'); do echo $i; done

    temp_size_b_total=0
    printf "\t%-10s %-35s\n" "SIZE" "LOCATION"
    for i in $(echo $(docker image inspect -f {{.GraphDriver.Data.WorkDir}} $d_image_id_short) | tr ":" "\n"); 
    do 
        temp=$(sudo du -sh $i)
        temp_size=$(echo $temp | awk '{print $1}')
        temp_loc=$(echo $temp | awk '{print $2}')
        printf "\t%-10s %-35s\n" "$temp_size" "$temp_loc"

        temp_size_b=$( echo $temp_size | \
                                sed 's/[bB]//g' | \
                                tr '[:lower:]' '[:upper:]' | \
                                numfmt --from=iec )
        temp_size_b_total=$(($temp_size_b_total + $temp_size_b))

    done
        temp_size_total=$(numfmt --to=iec --format %.1f $temp_size_b_total)
        printf "\t%-10s %-35s\n" "$temp_size_total" ""


    #------------------------------------------------------------------------


    echo ""
    echo "${cyan}------------------------------------------------------------------------"
    echo ""
    echo "${cyan}MOUNTED VOLUMES (${green}$d_name${cyan})"
    echo "[manually check sizes if needed]"
    echo ""
    
    # This gets the local mapping locations only
        #docker inspect -f "{{.Mounts}}" $d_id_short | \
        #    tr ' ' '\n' | \
        #    sed '/bind\|true\|false\|ro\|rw\|{\|}\|\/dev\|localtime/d' | \
        #    sed '/^$/d' | \
        #    sed -n '0~2!p' | \
        #    sed 's/^/\t/'
    
    # Get both sides of mapping
        docker inspect -f "{{.HostConfig.Binds}}" $d_id_short | \
            tr ' ' '\n' | \
            sed 's/\:ro\|:rw//g' | \
            tr -d [ | \
            tr -d ] | \
            sed 's/:/\n     ----\> /g' | \
            sed 's/^/\t/'

    echo ""; echo ""; echo ""; echo ""


    # exit if container name passed into script
    if [[ $1 != "" ]]; then
        exit
    fi


    echo "${cyan}=================================================================================================================="

done


    echo ""
    echo "${blue}SUMMARIES (${green}$d_name${blue})"
    echo "[manually check sizes if needed]"
    echo ""

#CONVERT SUMMED SIZES BACK TO HUMAN READABLE
echo "CONTAINER SIZES - TOTAL"
echo $d_container_size_b_total
echo $(numfmt --to=iec --format %.1f $d_container_size_b_total)
echo ""

echo "CONTAINER SIZES (VIRTUAL) - TOTAL"
echo $d_container_size_virtual_b_total
echo $(numfmt --to=iec --format %.1f $d_container_size_virtual_b_total)
echo ""
echo ""

echo "IMAGE SIZES - TOTAL"
echo $d_image_size_b_total
echo $(numfmt --to=iec --format %.1f $d_image_size_b_total)
echo ""

echo "IMAGE SIZES - SHARED - TOTAL"
echo $d_image_size_shared_b_total
echo $(numfmt --to=iec --format %.1f $d_image_size_shared_b_total)
echo ""

echo "IMAGE SIZES - UNIQUE - TOTAL"
echo $d_image_size_unique_b_total
echo $(numfmt --to=iec --format %.1f $d_image_size_unique_b_total)
echo ""


# docker system df
docker system df | sed 's/^/\t/'





################################################################################################################################
###### UNNAMED VOLUMES
################################################################################################################################

echo ""
echo "${yellow}=================================================================================================================="
echo ""
echo "'UNNAMED' VOLUMES"
echo ""

#Loop over all volumes
for docker_volume_id in $(docker volume ls -q); do
    echo "${yellow}VOLUME: ${green}${docker_volume_id}"
    
    #Obtain the size of the data volume by starting a docker container
    #that uses this data volume and determines the size of this data volume 
    docker_volume_size=$(docker run --rm -t -v ${docker_volume_id}:/volume_data alpine sh -c "du -hs /volume_data | cut -f1" ) 

    echo "    ${yellow}Size: ${magenta}${docker_volume_size}"
    
    #Determine the number of stopped and running containers that have a connection to this data 
    # volume
    num_related_containers=$(docker ps -a --filter=volume=${docker_volume_id} -q | wc -l)

    #If the number is non-zero, we show the information about the container and the image
    #and otherwise we show the message that are no connected containers
    if (( $num_related_containers > 0 )) 
    then
        echo "    ${yellow}Connected containers:"
        docker ps -a --filter=volume=${docker_volume_id} --format "{{.Names}} [{{.Image}}] ({{.Status}})" | while read containerDetails
        do
            echo "${cyan}        ${containerDetails}"
        done
    else
        echo "${cyan}    No connected containers"
    fi
    
    echo
done

echo "${yellow}=================================================================================================================="
echo ""








################################################################################################################################
###### LOG FILE SUMMARY
################################################################################################################################


echo ""
echo "${magenta}=================================================================================================================="
echo ""
echo "CONTAINER LOG SIZES SUMMARY${yellow}"
echo ""
printf "%-10s %35s %12s\n" "LOG SIZE" "CONTAINER" "ID (short)"

TOTALSIZE_LOGS_K=0
echo " ${yellow}"

sudo sh -c "du -sk /var/lib/docker/containers/*/*.log" | sort -rn | while read -r line ; do

    SIZE_LOGS_K=$(echo $line | awk '{print $1}')
    SIZE_LOGS_H=$(numfmt --from-unit=K --to=si --format %.1f $SIZE_LOGS_K)
    TOTALSIZE_LOGS_K=$(($TOTALSIZE_LOGS_K + $SIZE_LOGS_K))

    LOGPATH=$(echo $line | awk '{print $2}')
    LOGFILE=$(basename "$LOGPATH")
    ID=$(echo $LOGFILE | sed 's/.........$//')
    ID_SHORT=$(echo $ID | head -c 12)
    CONTAINER_NAME=$(docker inspect -f {{.Name}} $ID | sed 's/^.//')
    
    printf "%-10s %35s %12s\n" "$SIZE_LOGS_H" "$CONTAINER_NAME" "$ID_SHORT"
    
done

TOTALSIZE_LOGS_H=$(numfmt --from-unit=K --to=si --format %.1f $TOTALSIZE_LOGS_K)
#echo "TOTAL SIZE: $TOTALSIZE_LOGS_H"


echo ""
echo "${magenta}=================================================================================================================="
echo ""