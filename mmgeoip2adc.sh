#!/bin/bash
# mmgeoip2adc.sh
# This script will automate the download and update of the Citrix ADC InBuilt geoip location db files based on the Maxmind GeoLite2 or GeoIP2 IP DB.
# Please refer to README.md for more detailed information

set -o pipefail

# Local Variables
DBTYPE="City" #Choose Country or City
LANGUAGE="en" #Choose en, de, fr, es, jp, pt-BR, ru, or zh"
LOGFILE="$(date '+%m%d%Y')-mmgeoip2adc.log"
CONVERSION_TOOL="Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl"
CITRIX_ADC_GEOIPDB_PATH="/var/netscaler/inbuilt_db"

# Do Cleanup function
function do_cleanup {
echo "Cleaning up disposable files..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
rm -f *.csv* *.txt *.zip* Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6
echo "Searching for old logs > 30 days and removing them..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
find *.log -type f -not -name '*mmgeoip2adc-init.log' -mtime -30 -delete
}

# Initiate Log
echo "User $(whoami) started the script" | ts '[%H:%M:%S]' | tee -a $LOGFILE
echo "Starting MaxMindGeoIP2ADC Log..." | ts '[%H:%M:%S]' | tee -a $LOGFILE

# Check to see if one of the required environment variables for the script is not set
source ~/.bashrc
if [[ -z "${LICENSE_KEY}" || -z "${EDITION}" || -z "${CITRIX_ADC_USER}" || -z "${CITRIX_ADC_PASSWORD}" || -z "${CITRIX_ADC_IP}" || -z "${CITRIX_ADC_PORT}" ]]; then
    echo "One or more of the required environment variables for the script is not set properly..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
    exit 1;
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
      echo "Variable DBTYPE set to invalid option..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
      exit 1;
   ;;    
esac

# Check flags
while getopts 'f:u:' OPTION; do
  case "$OPTION" in
    f)
     FORCERUN = 1
      ;;
    u)
      echo "script usage: $(basename \$0) [-f] [-u]" >&2
      exit 1
      ;;
    *)
      FORCERUN = 0
      ;;
  esac
done

# Check to see if DB has been updated within the last 2 days
LAST_MODIFIED="$(curl -s -I "$GEOIPDB_URL" | grep -Fi Last-Modified: | awk {'print $3,$4,$5,$6'})"
echo "MaxMind $EDITION IP Database last modified: $LAST_MODIFIED" | ts '[%H:%M:%S]' | tee -a $LOGFILE
NOW=$(date | awk {'print $2,$3,$4,$5'})
let DIFF=($(date +%s -d "$NOW")-$(date +%s -d "$LAST_MODIFIED"))/86400
if [[ $DIFF -le 2 || $FORCERUN -eq 1 ]]; then #proceed with download of file
  echo "MaxMind $EDITION IP Database was updated $DIFF days ago, commencing with downlaod..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  # Download the file
  echo "Downloading $GEOIPDB_URL...";
  GEOIPDB_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_URL" | awk {'print $1'});
  #echo "GeoIP DB File: $GEOIPDB_FILE";
  GEOIPDB_CHECKSUM_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_CHECKSUM" | awk {'print $1'});
  #echo "GeoIP DB Checksum File: $GEOIPDB_CHECKSUM_FILE";
  echo "The  MaxMind $EDITION IP Database and checksum files for $DBTYPE successfully downloaded..."  | ts '[%H:%M:%S]' | tee -a $LOGFILE;
else
  # Exit if file has not been updated
  echo "The MaxMind $EDITION IP Database file has not been updated.  Exiting..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  exit;
fi

# Compare downloaded file to checksum and start file processing
echo "Comparing sha256 checksum to verify file integrity before preoceeding..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
CHECKSUM=$(sha256sum -c $GEOIPDB_CHECKSUM_FILE | awk {'print $2'}) 
if [[ "$CHECKSUM" == "OK" ]]; then #convert and transfer file to ADC
   echo "The MaxMind $EDITION Database file checksum is verified. Unpacking archive for conversion..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   # Unzip the MaxMind IP DB
   unzip -q -j $GEOIPDB_FILE;
   echo "Unzipped $GEOIPDB_FILE..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   #Run the Citrix tool to convert the geoip files to NetScaler format
   if [ -f "$CONVERSION_TOOL" ]; then
      echo "Running the Citrix conversion tool to convert the geoip db files to NetScaler format..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
      perl $CONVERSION_TOOL -b $EDITION-$DBTYPE-Blocks-IPv4.csv -i $EDITION-$DBTYPE-Blocks-IPv6.csv -l  $EDITION-$DBTYPE-Locations-$LANGUAGE.csv -o Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -p Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -logfile $LOGFILE;
      echo "Successfully converted MaxMind $EDITION IP Database files to NetScaler format..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   else 
      echo "The Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl was not present, please refer to the README.md for the script requirements - Exiting..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
      do_cleanup;
      exit 1;
   fi
   # Unzip converted files
   echo "Preparing files for transfer to ADC..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   gunzip Citrix_Netscaler_InBuilt_GeoIP_DB*;   
 
   # Transfer the files to the ADC
   echo "Transfering files to ADC..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   sshpass -p "$CITRIX_ADC_PASSWORD" scp -q -P $CITRIX_ADC_PORT Citrix_Netscaler_InBuilt_GeoIP_DB_IPv* $CITRIX_ADC_USER@$CITRIX_ADC_IP:$CITRIX_ADC_GEOIPDB_PATH;
   echo "Adding IPv4 and IPv6 GeoIP location files to ADC configuration for use in GSLB and PI..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   # Add the location db files (benign if already present in config)
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh -q $CITRIX_ADC_USER@$CITRIX_ADC_IP -p $CITRIX_ADC_PORT "add locationFile $CITRIX_ADC_GEOIPDB_PATH/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -format netscaler";
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh -q $CITRIX_ADC_USER@$CITRIX_ADC_IP -p $CITRIX_ADC_PORT "add locationFile6 $CITRIX_ADC_GEOIPDB_PATH/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -format netscaler";
   # Save the ns.conf - this will also invoke the filesync process to synchronize the db files to ha peer nodes or cluster nodes (note - watchdog will also eventually do this)
   echo "Saving configuration and invoking filesync..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh -q $CITRIX_ADC_USER@$CITRIX_ADC_IP -p $CITRIX_ADC_PORT "save config"
else
  echo "The checksum failed.  File is corrupt or tampered with in transit..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  do_cleanup;
  exit 1;
fi

do_cleanup
echo "All done..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
exit 0
