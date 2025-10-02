#!/bin/bash

# ==========================
# Radarr custom notifications
# ==========================
#
# Wrote this quick script to send custom notification which also includes SIZE of file grabbed. 
# This was missing from default notification and is kinda important so we're not downloading
# inappropriately large files.
#
# Only configuring for grabbing epidodes since existing notifications are fine for downloads etc.
#
# Save in /storage/Docker/radarr/data since it gets mounted to /config
# Save custom_notify.conf file in same directory.
#
# Relevant env vars on grab: https://wiki.servarr.com/Radarr_Tips_and_Tricks
# $radarr_movie_title
# $radarr_release_title
# $radarr_release_indexer
# $radarr_release_size
# $radarr_release_quality

# Set some vars for testing
    #radarr_release_size=100000
    #radarr_movie_title="Spiderman"
    #radarr_release_quality="HDTV-720p"
    #radarr_release_indexer="piratebay"

# When adding to radarr it sometimes gets hung up for no reason when clicking OK on the custom script dialogue.
# We can 'bypass' the script success checking by adding below exit command right here.
# Remember to comment out after adding script in sonarr GUI.
#exit





# Get sensitive info from .conf file
CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
typeset -A secrets    # Define array to hold variables 
while read line; do
  if echo $line | grep -F = &>/dev/null; then
    varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
  fi
done < $CONF_DIR/custom_notify.conf
#echo ${secrets[PO_API_TOKEN]}; echo ${secrets[PO_USER_KEY]}; echo ${secrets[SL_WEBHOOK_URL]}; echo ${secrets[PB_API_KEY]}


# Format size
FILESIZE=$(numfmt --from=si --to=si --format %.1f $radarr_release_size)


# Create Title
TITLE="Grabbed: "
TITLE+=$radarr_movie_title

# Create Message
MESSAGE=$radarr_movie_title
MESSAGE+=" [" 
MESSAGE+=$FILESIZE
MESSAGE+="]" 
MESSAGE+=" [" 
MESSAGE+=$radarr_release_quality
MESSAGE+="]" 
MESSAGE+=" [" 
MESSAGE+=$radarr_release_indexer
MESSAGE+="]" 

# Echo for testing manually
    #echo $TITLE
    #echo $MESSAGE


# Pushover notification
    po_api_url="https://api.pushover.net/1/messages.json"
    po_api_token="${secrets[PO_API_TOKEN]}"
    po_user_key="${secrets[PO_USER_KEY]}"
    curl -s -o /dev/null \
        --form-string "token=${po_api_token}" \
        --form-string "user=${po_user_key}" \
        --form-string "message=${MESSAGE}" \
        ${title:+ --form-string "title=${TITLE}"} \
        "${po_api_url}" > /dev/null 2>&1

# Slack notification
    sl_webhook_url=${secrets[SL_WEBHOOK_URL]}
    sl_channel="#media_stack"
    sl_username="radarr"
    sl_icon=":movie_camera:"
    echo "{ " > /tmp/slack_payload
        echo -n "\"username\": \"${sl_username}\", " >> /tmp/slack_payload
        echo -n "\"text\": \"Grabbed: ${TITLE}\", " >> /tmp/slack_payload
        echo -n "\"channel\": \"${sl_channel}\", " >> /tmp/slack_payload
        echo -n "\"icon_emoji\": \"${sl_icon}\", " >> /tmp/slack_payload
        echo -n "\"attachments\": [{ " >> /tmp/slack_payload
            echo -n "\"title\": \"${TITLE}\", " >> /tmp/slack_payload
            echo -n "\"text\": \"${MESSAGE}\" " >> /tmp/slack_payload
            echo -n " }]" >> /tmp/slack_payload
    echo -n " }" >> /tmp/slack_payload
    curl -s -S -X POST --data-urlencode "payload=$(< /tmp/slack_payload)" "${sl_webhook_url}"

# Pushbullet Notification
#    pb_api_key="${secrets[PB_API_KEY]}"
#    curl -s -o /dev/null \
#        -u $pb_api_key: https://api.pushbullet.com/v2/pushes \
#        -d type=note \
#        -d title="$TITLE" \
#        -d body="$MESSAGE"
