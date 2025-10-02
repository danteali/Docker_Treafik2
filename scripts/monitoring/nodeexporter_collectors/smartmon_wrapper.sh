#!/bin/sh

# Wrapper script for smartmon monitoring since the following crontab line didn't work:
# 10 * * * * /home/ryan/scripts/docker/scripts/monitoring/nodeexporter_collectors/smartmon_v3.sh | sponge /storage/Docker/nodeexporter/textfile_collector/smartmon.prom # Prometheus - SMART stats

# Instead call this script from crontab


sudo /home/ryan/scripts/docker/scripts/monitoring/nodeexporter_collectors/smartmon_v3.sh | sudo sponge /storage/Docker/nodeexporter/textfile_collector/smartmon.prom
