#!/bin/bash

# Script to run speedtest command and pass output to Prometheus/VictoriaMetrics via NodeExporter's textfile functionality.

# Created to replace previous speedtest metrics where the speedtest binary was passed to telegraf
# and telegraf ran the speedtest command every 2 min, parsed the output, and passed into InfluxDB.

#===============================================================================

# COMMAND DETAILS

# Command output samples are at the bottom of this script.

# The telegraf command was:
# /usr/bin/speedtest -f json-pretty --accept-license --accept-gdpr

# Command upload/download speed output is in Mbps
# Ping & Jitter is in ms

# Machine readable formats (csv, tsv, json, jsonl, json-pretty) use bytes
# as the unit of measure with max precision

# Command we will run:
# /usr/bin/speedtest -p 4 -f json-pretty

#===============================================================================

# OUTPUT METRICS

# The telegraf produced metrics in VictoriaMetrics were:
# Speedtest_download_bandwidth{db="telegraf",host="crush"}
# Speedtest_download_bandwidth{db="telegraf",host="crush"}
# Speedtest_ping_jitter{db="telegraf",host="crush"}
# Speedtest_ping_latency{db="telegraf",host="crush"}

# We could replicate the metrics exactly (aside from label names) to preserve continuity with historic data
# but it's not that important as we can retain the historic data in the same Grafana chart using the
# existing queries and just add new queries to append the new data.

# Our output metrics
# speedtest_download_bandwidth_bytes{host="crush",interface="enp4s0",externalip="212.159.26.42",serverid="17629",serverlocation="Manchester"}
# speedtest_upload_bandwidth_bytes{host="crush",interface="enp4s0",externalip="212.159.26.42",serverid="17629",serverlocation="Manchester"}
# speedtest_ping_jitter_ms{host="crush",interface="enp4s0",externalip="212.159.26.42",serverid="17629",serverlocation="Manchester"}
# speedtest_ping_latency_ms{host="crush",interface="enp4s0",externalip="212.159.26.42",serverid="17629",serverlocation="Manchester"}

# Note that metrics via NodeExporter automatically have these additional labels added:
# {instance="nodeexporter:9100",job="nodeexporter",monitor="docker-host-alpha"}

#===============================================================================

# Set temp files for working
# $$ returns current process PID, used below to create temp file.
# $(basename "$0") returns filename of this script
# If we want to be even tidier we could also remove extension with: ${FILENAME%%.*}
THISFILENAME=$(basename "$0")
TEMPMETRICS="/tmp/${THISFILENAME%%.*}.$$_metrics"
TEMPCMDOUT="/tmp/${THISFILENAME%%.*}.$$_cmdout"
DATETIME="$(date +%Y%m%d_%H%M%S)"

# Specify where output file should be saved. This should be where nodeexporter looks for the files.
OUTPUTFILE="/storage/Docker/nodeexporter/textfile_collector/speedtest.prom"

# Run command and save output
/usr/bin/speedtest -f json-pretty > "$TEMPCMDOUT"

# Get label values
VARINTF="$(jq -r .interface.name "$TEMPCMDOUT")"
VAREXTIP="$(jq -r .interface.externalIp "$TEMPCMDOUT")"
VARSERVID="$(jq -r .server.id "$TEMPCMDOUT")"
VARSERVLOC="$(jq -r .server.location "$TEMPCMDOUT")"

# Create metrics file
echo "#$DATETIME" > "$TEMPMETRICS"

{
    echo "# HELP speedtest_download_bandwidth_bytes ISP Download Speed"
    echo "# TYPE speedtest_download_bandwidth_bytes gauge"
    echo "speedtest_download_bandwidth_bytes{host=\"$HOSTNAME\",interface=\"$VARINTF\",externalip=\"$VAREXTIP\",serverid=\"$VARSERVID\",serverlocation=\"$VARSERVLOC\"} $(jq -r .download.bandwidth "$TEMPCMDOUT")"

    echo "# HELP speedtest_upload_bandwidth_bytes ISP Upload Speed"
    echo "# TYPE speedtest_upload_bandwidth_bytes gauge"
    echo "speedtest_upload_bandwidth_bytes{host=\"$HOSTNAME\",interface=\"$VARINTF\",externalip=\"$VAREXTIP\",serverid=\"$VARSERVID\",serverlocation=\"$VARSERVLOC\"} $(jq -r .upload.bandwidth "$TEMPCMDOUT")"

    echo "# HELP speedtest_ping_jitter_ms ISP Jitter"
    echo "# TYPE speedtest_ping_jitter_ms gauge"
    echo "speedtest_ping_jitter_ms{host=\"$HOSTNAME\",interface=\"$VARINTF\",externalip=\"$VAREXTIP\",serverid=\"$VARSERVID\",serverlocation=\"$VARSERVLOC\"} $(jq -r .ping.jitter "$TEMPCMDOUT")"

    echo "# HELP speedtest_ping_latency_ms ISP Ping"
    echo "# TYPE speedtest_ping_latency_ms gauge"
    echo "speedtest_ping_latency_ms{host=\"$HOSTNAME\",interface=\"$VARINTF\",externalip=\"$VAREXTIP\",serverid=\"$VARSERVID\",serverlocation=\"$VARSERVLOC\"} $(jq -r .ping.latency "$TEMPCMDOUT")"
} >> "$TEMPMETRICS"

# Copy metrics file to nodeexporter directory
cp "$TEMPMETRICS" "$OUTPUTFILE"

# Delete temp files
rm "$TEMPMETRICS"
rm "$TEMPCMDOUT"


#===============================================================================
# COMMAND OUTPUT SAMPLES

#/usr/bin/speedtest | tee /tmp/speedtest-default.txt
#
#   Speedtest by Ookla
#
#      Server: Exascale - Manchester (id: 17629)
#         ISP: Plusnet
#Idle Latency:    19.94 ms   (jitter: 0.05ms, low: 19.88ms, high: 20.02ms)
#    Download:   149.56 Mbps (data used: 156.0 MB)                                                   
#                 40.24 ms   (jitter: 4.10ms, low: 19.31ms, high: 293.34ms)
#      Upload:    28.68 Mbps (data used: 14.7 MB)                                                   
#                252.11 ms   (jitter: 68.47ms, low: 32.32ms, high: 406.90ms)
# Packet Loss:     0.0%
#  Result URL: https://www.speedtest.net/result/c/df57538d-6e1a-471b-ab78-7630a14bb336
  
#/usr/bin/speedtest -f json-pretty | tee /tmp/speedtest-json-pretty.txt
#{
#    "type": "result",
#    "timestamp": "2023-06-05T20:49:27Z",
#    "ping": {
#        "jitter": 0.102,
#        "latency": 17.973,
#        "low": 17.834,
#        "high": 18.112
#    },
#    "download": {
#        "bandwidth": 18682105,
#        "bytes": 154205280,
#        "elapsed": 8314,
#        "latency": {
#            "iqm": 40.764,
#            "low": 19.834,
#            "high": 269.459,
#            "jitter": 3.786
#        }
#    },
#    "upload": {
#        "bandwidth": 3518010,
#        "bytes": 15134400,
#        "elapsed": 4300,
#        "latency": {
#            "iqm": 251.554,
#            "low": 19.444,
#            "high": 400.487,
#            "jitter": 69.573
#        }
#    },
#    "packetLoss": 0,
#    "isp": "Plusnet",
#    "interface": {
#        "internalIp": "192.168.0.10",
#        "name": "enp4s0",
#        "macAddr": "50:E5:49:CA:11:FF",
#        "isVpn": false,
#        "externalIp": "212.159.26.42"
#    },
#    "server": {
#        "id": 17629,
#        "host": "speedtest.man0.uk.as61049.net",
#        "port": 8080,
#        "name": "Exascale",
#        "location": "Manchester",
#        "country": "United Kingdom",
#        "ip": "185.195.119.42"
#    },
#    "result": {
#        "id": "00c37727-f541-43a2-93a2-eae7ac6c40ba",
#        "url": "https://www.speedtest.net/result/c/00c37727-f541-43a2-93a2-eae7ac6c40ba",
#        "persisted": true
#    }
#}

# /usr/bin/speedtest -f json | tee /tmp/speedtest-json.txt
# {"type":"result","timestamp":"2023-06-05T20:58:49Z","ping":{"jitter":0.252,"latency":20.084,"low":19.752,"high":20.325},"download":{"bandwidth":18671063,"bytes":155665440,"elapsed":8400,"latency":{"iqm":39.933,"low":19.541,"high":45.219,"jitter":1.141}},"upload":{"bandwidth":3571495,"bytes":13959360,"elapsed":3910,"latency":{"iqm":259.438,"low":22.679,"high":409.579,"jitter":70.549}},"packetLoss":0,"isp":"Plusnet","interface":{"internalIp":"192.168.0.10","name":"enp4s0","macAddr":"50:E5:49:CA:11:FF","isVpn":false,"externalIp":"212.159.26.42"},"server":{"id":17629,"host":"speedtest.man0.uk.as61049.net","port":8080,"name":"Exascale","location":"Manchester","country":"United Kingdom","ip":"185.195.119.42"},"result":{"id":"e4e7920c-8b2c-4c0a-af7a-1d7cdc3542c8","url":"https://www.speedtest.net/result/c/e4e7920c-8b2c-4c0a-af7a-1d7cdc3542c8","persisted":true}}

# /usr/bin/speedtest -f csv | tee /tmp/speedtest-csv.txt
# "FAELIX - Manchester","20746","19.9682","0.14775","0","18649959","3581626","155550240","15059520","https://www.speedtest.net/result/c/81b08102-25c1-4d5a-ba0b-12571c7617c8","1","41.45","1.2905","20.499","46.504","246.017","69.6153","36.628","387.82","19.795","20.185"