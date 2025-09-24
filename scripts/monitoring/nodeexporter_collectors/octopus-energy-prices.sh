#!/bin/bash

# Get Octopus Energy pricing via their API

# See OneNote for details of Octopus APIs etc.

# API docs: https://developer.octopus.energy/docs/api/#list-tariff-charges

# Using 'jq' to get latest pricing - assuming that current pricing has a 'null' value for 'valid_to' key
# Example json returned before jq parsing:
# Electricity Standing Charges
#{
#    "count": 2,
#    "next": null,
#    "previous": null,
#    "results":
#    [
#        {
#            "value_exc_vat": 47.03,
#            "value_inc_vat": 49.3815,
#            "valid_from": "2022-04-01T23:00:00Z",
#            "valid_to": null
#        },
#        {
#            "value_exc_vat": 23.68,
#            "value_inc_vat": 24.864,
#            "valid_from": "2021-09-28T23:00:00Z",
#            "valid_to": "2022-04-01T23:00:00Z"
#        }
#    ]
#}

# Get sensitive info from .conf file
CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
typeset -A secrets    # Define array to hold variables 
while read line; do
  if echo $line | grep -F = &>/dev/null; then
    varname=$(echo "$line" | cut -d '=' -f 1); secrets[$varname]=$(echo "$line" | cut -d '=' -f 2-)
  fi
done < $CONF_DIR/octopus-energy-prices.conf
#echo ${secrets[FQDN]}; echo ${secrets[APIKEY]}

APIKEY="${secrets[APIKEY]}"

# Product and tariff codes obtained from this site:
# https://energy.guylipman.com/sm/admin?octopus=A-8EE8964Fsk_live_txkuMRph6YPJkibcC6dp01i7&mode=110
PRODUCT_CODE="VAR-22-11-01" #"VAR-21-09-29"
TARIFF_CODE_ELECTRICITY="E-1R-VAR-22-11-01-N" # "E-1R-VAR-21-09-29-N"
TARIFF_CODE_GAS="G-1R-VAR-22-11-01-N" # "G-1R-VAR-21-09-29-N"

# Specify where output file should be saved. This should be where nodeexporter looks for the files.
OUTPUTFILE=/storage/Docker/nodeexporter/textfile_collector/octopus_energy_prices.prom

# Set temp files for working
# $$ returns current process PID, used below to create temp file.
# $(basename "$0") returns filename of this script
# If we want to be even tidier we could also remove extension with: ${FILENAME%%.*}
THISFILENAME=$(basename "$0")
TEMPFILE1="/tmp/${THISFILENAME%%.*}.$$_1"
TEMPFILECURL="/tmp/${THISFILENAME%%.*}.$$_curl"
DATETIME="$(date +%Y%m%d_%H%M%S)"

# Variable to test if returned value is a number
#ISNUMBER='^[0-9]+$'             # No decimals
ISNUMBER='^[0-9]+([.][0-9]+)?$'   # Allows decimals

# Run curl commands to get pricing
# Some tariffs don't have night/day pricing so jq will output an error when trying to parse the response - we test for numeric output to avoid passing jq error to nodeexporter
curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/electricity-tariffs/$TARIFF_CODE_ELECTRICITY/standing-charges/ > "$TEMPFILECURL"
STANDING_CHARGE_ELECTRICITY=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    STANDING_CHARGE_ELECTRICITY=$( cat "$TEMPFILECURL"  | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat')
    if ! [[ $STANDING_CHARGE_ELECTRICITY =~ $ISNUMBER ]]; then STANDING_CHARGE_ELECTRICITY="0"; fi
fi
#echo $STANDING_CHARGE_ELECTRICITY

curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/electricity-tariffs/$TARIFF_CODE_ELECTRICITY/standard-unit-rates/ > "$TEMPFILECURL"
UNIT_RATE_ELECTRICITY=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    UNIT_RATE_ELECTRICITY=$( cat "$TEMPFILECURL" | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat' )
    if ! [[ $UNIT_RATE_ELECTRICITY =~ $ISNUMBER ]]; then UNIT_RATE_ELECTRICITY="0"; fi
fi
#echo $UNIT_RATE_ELECTRICITY

curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/electricity-tariffs/$TARIFF_CODE_ELECTRICITY/day-unit-rates/ > "$TEMPFILECURL"
UNIT_RATE_DAY_ELECTRICITY=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    UNIT_RATE_DAY_ELECTRICITY=$( cat "$TEMPFILECURL" | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat' )
    if ! [[ $UNIT_RATE_DAY_ELECTRICITY =~ $ISNUMBER ]]; then UNIT_RATE_DAY_ELECTRICITY="0"; fi
fi
#echo $UNIT_RATE_DAY_ELECTRICITY

curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/electricity-tariffs/$TARIFF_CODE_ELECTRICITY/night-unit-rates/ > "$TEMPFILECURL"
UNIT_RATE_NIGHT_ELECTRICITY=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    UNIT_RATE_NIGHT_ELECTRICITY=$( cat "$TEMPFILECURL" | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat' )
    if ! [[ $UNIT_RATE_NIGHT_ELECTRICITY =~ $ISNUMBER ]]; then UNIT_RATE_NIGHT_ELECTRICITY="0"; fi
fi
#echo $UNIT_RATE_NIGHT_ELECTRICITY

curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/gas-tariffs/$TARIFF_CODE_GAS/standing-charges/ > "$TEMPFILECURL"
STANDING_CHARGE_GAS=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    STANDING_CHARGE_GAS=$( cat "$TEMPFILECURL" | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat' )
    if ! [[ $STANDING_CHARGE_GAS =~ $ISNUMBER ]]; then STANDING_CHARGE_GAS="0"; fi
fi
#echo $STANDING_CHARGE_GAS

curl -s -u "${APIKEY}:" https://api.octopus.energy/v1/products/$PRODUCT_CODE/gas-tariffs/$TARIFF_CODE_GAS/standard-unit-rates/ > "$TEMPFILECURL"
UNIT_RATE_GAS=0
if [[ $(cat "$TEMPFILECURL") = *"value_exc_vat"* ]]; then 
    UNIT_RATE_GAS=$( cat "$TEMPFILECURL" | jq '.results[] | select(.payment_method == "DIRECT_DEBIT") | select(.valid_to == null) | .value_inc_vat' )
    if ! [[ $UNIT_RATE_GAS =~ $ISNUMBER ]]; then UNIT_RATE_GAS="0"; fi
fi
#echo $UNIT_RATE_GAS


echo "#$DATETIME" > "$TEMPFILE1"
echo "node_octopus_energy_standingcharge_electricity_pence{source=\"electricity\", category=\"standing charge\"} $STANDING_CHARGE_ELECTRICITY" >> "$TEMPFILE1"
echo "node_octopus_energy_unitrate_electricity_pence{source=\"electricity\", category=\"unit rate\"} $UNIT_RATE_ELECTRICITY" >> "$TEMPFILE1"
echo "node_octopus_energy_unitrate_day_electricity_pence{source=\"electricity\", category=\"unit rate day\"} $UNIT_RATE_DAY_ELECTRICITY" >> "$TEMPFILE1"
echo "node_octopus_energy_unitrate_night_electricity_pence{source=\"electricity\", category=\"unit rate night\"} $UNIT_RATE_NIGHT_ELECTRICITY" >> "$TEMPFILE1"
echo "node_octopus_energy_standingcharge_gas_pence{source=\"gas\", category=\"standing charge\"} $STANDING_CHARGE_GAS" >> "$TEMPFILE1"
echo "node_octopus_energy_unitrate_gas_pence{source=\"gas\", category=\"unit rate\"} $UNIT_RATE_GAS" >> "$TEMPFILE1"

mv "$TEMPFILE1" "$OUTPUTFILE"

#rm $TEMPFILE1
rm "$TEMPFILECURL"