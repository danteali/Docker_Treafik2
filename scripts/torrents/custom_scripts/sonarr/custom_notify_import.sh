#!/bin/bash

# ==========================
# Sonar custom notifications
# ==========================
#
# Wrote this quick script to send custom notification when file imported.
# This was missing from default notification and is kinda important so we're not downloading
# inappropriately large files.
#
# Save in /storage/Docker/sonarr/data since it gets mounted to /config
# Save custom_notify.conf file in same directory.
#
# Relevant env vars on download:
# https://github.com/Sonarr/Sonarr/wiki/Custom-Post-Processing-Scripts#on-downloadon-upgrade
#
# $sonarr_isupgrade
# $sonarr_series_title
# $sonarr_episodefile_seasonnumber
# $sonarr_episodefile_episodenumbers
# $sonarr_episodefile_episodetitles
#
# Relevant env vars on download/upgrade (all above plus...): https://github.com/Sonarr/Sonarr/wiki/Custom-Post-Processing-Scripts#on-downloadon-upgrade
# $sonarr_episodefile_id

# Set some vars for testing
#    sonarr_release_size=100000
#    sonarr_series_title="Paul Hollywood City Bakes"
#    sonarr_release_episodenumbers="06"
#    sonarr_release_seasonnumber="1"
#    sonarr_release_episodetitles="Copenhagen"
#    sonarr_release_quality="HDTV-720p"
#    sonarr_release_indexer="piratebay"

# Get sensitive info from .conf file
CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
typeset -A secrets    # Define array to hold variables 
while read line; do
  if echo $line | grep -F = &>/dev/null; then
    varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
  fi
done < $CONF_DIR/custom_notify.conf
#echo ${secrets[PO_API_TOKEN]}; echo ${secrets[PO_USER_KEY]}; echo ${secrets[SL_WEBHOOK_URL]}; echo ${secrets[PB_API_KEY]}


# Create Title
TITLE="Downloaded: "
TITLE+=$sonarr_series_title
TITLE+=" - " 
TITLE+=$sonarr_episodefile_seasonnumber
TITLE+="x"
TITLE+=$sonarr_episodefile_episodenumbers

# Create Message
MESSAGE+="Downloaded: " 
MESSAGE+=$sonarr_series_title
MESSAGE+=" - " 
MESSAGE+=$sonarr_episodefile_seasonnumber
MESSAGE+="x"
MESSAGE+=$sonarr_episodefile_episodenumbers
MESSAGE+=" (Upgrade: "
MESSAGE+=$sonarr_isupgrade
MESSAGE+=")"



# For testing 
#    echo $TITLE
#    echo $MESSAGE


# Pushover notification
# Existing:
    # App: media_stack = a1uy6cvqkgewfiqcxz79yeok6b6kvh
    # Title: Episode Grabbed
    # Message: Paul Hollywood City Bakes - 1x06 - Copenhagen [HDTV-720p]
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
# Existing:
    # username: sonarr
    # text: Grabbed: Paul Hollywood City Bakes - 1x06 - Copenhagen [HDTV-720p]
    # attachment_title: Paul Hollywood City Bakes
    # attachment_text: Paul Hollywood City Bakes - 1x06 - Copenhagen [HDTV-720p]
    # channel: #media_stack
    # emoji: :tv:
    sl_webhook_url=${secrets[SL_WEBHOOK_URL]}
    sl_channel="#media_stack"
    sl_username="sonarr"
    sl_icon=":tv:"
    echo "{ " > /tmp/slack_payload
        echo -n "\"username\": \"${sl_username}\", " >> /tmp/slack_payload
        echo -n "\"text\": \"${TITLE}\", " >> /tmp/slack_payload
        echo -n "\"channel\": \"${sl_channel}\", " >> /tmp/slack_payload
        echo -n "\"icon_emoji\": \"${sl_icon}\", " >> /tmp/slack_payload
        echo -n "\"attachments\": [{ " >> /tmp/slack_payload
            echo -n "\"title\": \"${sonarr_series_title}\", " >> /tmp/slack_payload
            echo -n "\"text\": \"${MESSAGE}\" " >> /tmp/slack_payload
            echo -n " }]" >> /tmp/slack_payload
    echo -n " }" >> /tmp/slack_payload
    curl -s -S -X POST --data-urlencode "payload=$(< /tmp/slack_payload)" "${sl_webhook_url}"

# Pushbullet Notification
# Existing:
    # Title: Sonarr - Episode Grabbed
    # Message: Paul Hollywood City Bakes - 1x06 - Copenhagen [HDTV-720p]
#    pb_api_key="${secrets[PB_API_KEY]}"
#    curl -s -o /dev/null \
#        -u $pb_api_key: https://api.pushbullet.com/v2/pushes \
#        -d type=note \
#        -d title="$TITLE" \
#        -d body="$MESSAGE"
