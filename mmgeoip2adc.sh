#!/bin/bash
# mmgeoip2adc.sh
# This script will automate the download and update of the Citrix ADC InBuilt geoip location db files based on the Maxmind GeoLite2 or GeoIP2 IP DB.
# Please refer to README.md for more detailed information

set -o pipefail

(
# Local Variables
DBTYPE="City" #Choose Country or City
LANGUAGE="en" #Choose en, de, fr, es, jp, pt-BR, ru, or zh"
LOGFILE="./log/$(date '+%m%d%Y')-mmgeoip2adc.log"
CONVERSION_TOOL="Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl"
MMGEOIP2ADC_ADC_GEOIPDB_PATH="/var/netscaler/inbuilt_db"

# Do Cleanup function
function do_cleanup {
echo "Cleaning up disposable files..."
rm -f *.csv* *.txt *.zip* Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6
echo "Searching for old logs > 30 days and removing them..."
find ./log/*.log -type f -not -name '*mmgeoip2adc-init.log' -mtime +30 -delete
}

# Check flags and initiate log
while getopts 'fu' OPTION; do
  case "$OPTION" in
    f)
      FORCERUN=true
      # Initiate Log
      echo "User $(whoami) started the script" | ts '[%H:%M:%S]' | tee -a $LOGFILE
      echo "Starting MaxMindGeoIP2ADC Log..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
      echo "Force parameter detected - skipping freshness check..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
      ;;
    u)
      echo "script usage: $(basename $0) [-f] [-u]" >&2
      exit 1
      ;;
    ?)
      echo "script usage: $(basename $0) [-f] [-u]" >&2
      exit 1
      ;;
    *)
      FORCERUN=false
      # Initiate Log
      echo "User $(whoami) started the script" | ts '[%H:%M:%S]' | tee -a $LOGFILE
      echo "Starting MaxMindGeoIP2ADC Log..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
      ;;
  esac
done

# Check to see if one of the required environment variables for the script is not set
source ~/.bashrc
if [ -z "$LICENSE_KEY" ] || [ -z "EDITION" ] || [ -z "$MMGEOIP2ADC_ADC_USER" ] || [ -z "$MMGEOIP2ADC_ADC_PASSWORD" ] || [ -z "$MMGEOIP2ADC_ADC_IP" ] || [ -z "$MMGEOIP2ADC_ADC_PORT" ] || [ -z "$SSHPASS" ]; then
    echo "One or more of the required environment variables for the script is not set properly..."
    exit 1
fi

# Set GEODB_URL and GEODB_CHECKSUM based on DBTYPE variable
case $DBTYPE in
   "Country")
      # Use permalinks for the Country GeoIPDB
      GEOIPDB_URL="https://download.maxmind.com/app/geoip_download?edition_id=${EDITION}-Country-CSV&license_key=${LICENSE_KEY}&suffix=zip"
      GEOIPDB_CHECKSUM="https://download.maxmind.com/app/geoip_download?edition_id=${EDITION}-Country-CSV&license_key=${LICENSE_KEY}&suffix=zip.sha256"
   ;;
   "City")
	    # Use permalinks for the City GeoIPDB
      GEOIPDB_URL="https://download.maxmind.com/app/geoip_download?edition_id=${EDITION}-City-CSV&license_key=${LICENSE_KEY}&suffix=zip"
      GEOIPDB_CHECKSUM="https://download.maxmind.com/app/geoip_download?edition_id=${EDITION}-City-CSV&license_key=${LICENSE_KEY}&suffix=zip.sha256"
	 ;;
   *)
      # Invalid DBTYPE set
      echo "Variable DBTYPE set to invalid option..."
      exit 1
   ;;    
esac

# Check to see if DB has been updated within the last 2 days
LAST_MODIFIED="$(curl -s -I "$GEOIPDB_URL" | grep -Fi Last-Modified: | awk {'print $3,$4,$5,$6'})"
echo "MaxMind $EDITION IP Database last modified: $LAST_MODIFIED"
NOW=$(date | awk {'print $2,$3,$4,$5'})
let DIFF=($(date +%s -d "$NOW")-$(date +%s -d "$LAST_MODIFIED"))/86400
if [[ $DIFF -le 2 || $FORCERUN ]]; then #proceed with download of file
  echo "MaxMind $EDITION IP Database was updated 2 or fewer days ago or force paramter specified, commencing with downlaod..."
  # Download the file
  echo "Downloading $GEOIPDB_URL..."
  GEOIPDB_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_URL" | awk {'print $1'})
  #echo "GeoIP DB File: $GEOIPDB_FILE"
  GEOIPDB_CHECKSUM_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_CHECKSUM" | awk {'print $1'})
  #echo "GeoIP DB Checksum File: $GEOIPDB_CHECKSUM_FILE"
  echo "The  MaxMind $EDITION IP Database and checksum files for $DBTYPE successfully downloaded..."
else
  # Exit if file has not been updated
  echo "The MaxMind $EDITION IP Database file has not been updated.  Exiting..."
  exit
fi

# Compare downloaded file to checksum and start file processing
echo "Comparing sha256 checksum to verify file integrity before preoceeding..."
CHECKSUM=$(sha256sum -c $GEOIPDB_CHECKSUM_FILE | awk {'print $2'}) 
if [[ "$CHECKSUM" == "OK" ]]; then #convert and transfer file to ADC
   echo "The MaxMind $EDITION Database file checksum is verified. Unpacking archive for conversion..."
   # Unzip the MaxMind IP DB
   unzip -q -j $GEOIPDB_FILE
   echo "Unzipped $GEOIPDB_FILE..."
   # Run the Citrix tool to convert the geoip files to NetScaler format
   if [ -f "$CONVERSION_TOOL" ]; then
      echo "Running the Citrix conversion tool to convert the geoip db files to NetScaler format..."
      perl $CONVERSION_TOOL -b $EDITION-$DBTYPE-Blocks-IPv4.csv -i $EDITION-$DBTYPE-Blocks-IPv6.csv -l  $EDITION-$DBTYPE-Locations-$LANGUAGE.csv -o Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -p Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -logfile $LOGFILE
      echo "Successfully converted MaxMind $EDITION IP Database files to NetScaler format..."
   else 
      echo "The Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl was not present, please refer to the README.md for the script requirements - Exiting..."
      do_cleanup
      exit 1
   fi
   # Unzip converted files
   echo "Preparing files for transfer to ADC..."
   gunzip Citrix_Netscaler_InBuilt_GeoIP_DB*   
 
   # Transfer the files to the ADC
   echo "Transfering files to ADC..."
   sshpass -e  scp -q -P $MMGEOIP2ADC_ADC_PORT Citrix_Netscaler_InBuilt_GeoIP_DB_IPv* $MMGEOIP2ADC_ADC_USER@$MMGEOIP2ADC_ADC_IP:$MMGEOIP2ADC_ADC_GEOIPDB_PATH < /dev/null
   echo "Adding IPv4 and IPv6 GeoIP location files to ADC configuration for use in GSLB and PI..."
   # Add the location db files (benign if already present in config)
   sshpass -e ssh -q $MMGEOIP2ADC_ADC_USER@$MMGEOIP2ADC_ADC_IP -p $MMGEOIP2ADC_ADC_PORT "add locationFile $MMGEOIP2ADC_ADC_GEOIPDB_PATH/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -format netscaler"  < /dev/null
   sshpass -e ssh -q $MMGEOIP2ADC_ADC_USER@$MMGEOIP2ADC_ADC_IP -p $MMGEOIP2ADC_ADC_PORT "add locationFile6 $MMGEOIP2ADC_ADC_GEOIPDB_PATH/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -format netscaler" < /dev/null
   # Save the ns.conf - this will also invoke the filesync process to synchronize the db files to ha peer nodes or cluster nodes (note - watchdog will also eventually do this)
   echo "Saving configuration and invoking filesync..."
   sshpass -e ssh -q $MMGEOIP2ADC_ADC_USER@$MMGEOIP2ADC_ADC_IP -p $MMGEOIP2ADC_ADC_PORT "save config"  < /dev/null
else
  echo "The checksum failed.  File is corrupt or tampered with in transit..."
  do_cleanup
  exit 1
fi

do_cleanup

echo "All done..."
>> $LOGFILE) 2>&1 | ts '[%H:%M:%S]' | tee -a $LOGFILE