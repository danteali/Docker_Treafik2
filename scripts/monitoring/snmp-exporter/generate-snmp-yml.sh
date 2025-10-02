#!/bin/bash

# Uses generator.yml file to create new snmp.yml for use in SNMP Exporter
# See generator.yml syntax:
# https://github.com/prometheus/snmp_exporter/blob/main/generator/README.md#file-format

# Set file paths for network device MIBS and generator.yml to use to generate snmp.yml
# SNMPGENERATOR can be set via environment variable or else will use default location below.
SNMPMIBS="/root/scripts/docker/scripts/monitoring/snmp-exporter/ubiquity-mibs"
SNMPGENERATOR=${SNMPGENERATOR:="/root/scripts/docker/scripts/monitoring/snmp-exporter/generator.yml"}

# Specify generator file used to confirm to user that env var is successfully being used.
echo
echo "Using generator:"
echo "$SNMPGENERATOR"
echo

# Generate new snmp.yml
# Will be output to /tmp/snmp.yml
docker run --rm \
  --name snmp-generator \
  -v $SNMPMIBS:/root/.snmp/mibs:ro \
  -v $SNMPGENERATOR:/opt/generator.yml:ro \
  -v /tmp/:/opt/ \
  -e MIBDIRS="/root/.snmp/mibs" \
  prom/snmp-generator generate

# Exit Message
echo
echo "New snmp.yml can be found at: /tmp/snmp.yml"
echo "Copy to this script folder to retain a record of snmp.yml files."
echo
echo "Stop any existing SNMP Exporter service and restart after copying new file to:"
echo "/storage/Docker/snmp-exporter/data/snmp.yml"
echo
echo "cp /tmp/snmp.yml /root/scripts/docker/scripts/monitoring/snmp-exporter/; cp /tmp/snmp.yml /storage/Docker/snmp-exporter/data/"
echo

# For reference, SNMP Exporter can be run with docker run command:
# Use release tagged ':v0.22.0' if using older snmp.yml files.
#docker run --rm \
#    -p 9116:9116 \
#    --name snmp-exporter \
#    -v /storage/Docker/snmp-exporter/data/snmp.yml:/snmp.yml:ro \
#    prom/snmp-exporter --config.file=/snmp.yml

# Scrape with:
#scrape_configs:
#  - job_name: 'snmp'
#    static_configs:
#      - targets:
#        - 192.168.0.1  # SNMP device.
#    metrics_path: /snmp
#    params:
#      module: [ubiquiti_edgemax]
#    relabel_configs:
#      - source_labels: [__address__]
#        target_label: __param_target
#      - source_labels: [__param_target]
#        target_label: instance
#      - target_label: __address__
#        replacement: my-service-name:9116  # The SNMP exporter's Service name and port.