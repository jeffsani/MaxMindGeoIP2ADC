#!/bin/bash
# geolite2adc.sh
# This script will automate the download and update of the Citrix ADC InBuilt geoip location db files based on the Maxmind GeoLite2 IP DB.
# Please refer to README.md for more detailed information

set -o pipefail

# Local Variables
DBTYPE="Country" #Choose Country or City
LANGUAGE="en" #en, de, fr, es, jp, pt-BR, ru, or zh"
LOGFILE="$(date '+%m%d%Y')-maxmindgeolite2adc.log"
CONVERSION_TOOL="Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl"

# Constants
CITRIX_ADC_GEOIPDB_PATH="/var/netscaler/inbuilt_db"

# Do Cleanup function
function do_cleanup {
echo "Cleaning up disposable files..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
rm -f *.csv* *.txt *.zip* Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6
}

# Initiate Log
echo "User $(whoami) started the script" | ts '[%H:%M:%S]' | tee -a $LOGFILE
echo "Starting geolite2adc Log..." | ts '[%H:%M:%S]' | tee -a $LOGFILE

# Check to see if one of the required environment variables for the script is not set
if [[ -z "${LICENSE_KEY}" || -z "${CITRIX_ADC_USER}" || -z "${CITRIX_ADC_PASSWORD}" || -z "${CITRIX_ADC_IP}" ]]; then
    echo "One of the required environment variable for the script is not set properly..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
    exit 1;
fi

# Set GEODB_URL and GEODB_CHECKSUM based on DBTYPE variable
case $DBTYPE in
   "Country")
      # Use permalinks for the Country GeoIPDB
      GEOIPDB_URL="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${LICENSE_KEY}&suffix=zip"
      GEOIPDB_CHECKSUM="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${LICENSE_KEY}&suffix=zip.sha256"
   ;;
   "City")
	    # Use permalinks for the City GeoIPDB
      GEOIPDB_URL="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City-CSV&license_key=${LICENSE_KEY}&suffix=zip"
      GEOIPDB_CHECKSUM="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City-CSV&license_key=${LICENSE_KEY}&suffix=zip.sha256"
	 ;;
   *)
      # Invalid DBTYPE set
      echo "Variable DBTYPE set to invalid option..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
      exit 1;
   ;;    
esac

# Check to see if DB has been updated within the last 2 days
LAST_MODIFIED="$(curl -s -I "$GEOIPDB_URL" | grep -Fi Last-Modified: | awk {'print $3,$4,$5,$6'})"
echo "Maxmind GeoLite2 IP Database last modified: $LAST_MODIFIED" | ts '[%H:%M:%S]' | tee -a $LOGFILE
NOW=$(date | awk {'print $2,$3,$4,$5'})
let DIFF=($(date +%s -d "$NOW")-$(date +%s -d "$LAST_MODIFIED"))/86400
if [[ $DIFF -le 2 ]]; then #proceed with download of file
  echo "GeoLite2 DB is was updated $DIFF days ago, commencing with downlaod..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  # Download the file
  echo "Downloading $GEOIPDB_URL...";
  GEOIPDB_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_URL" | awk {'print $1'});
  #echo "GeoIP DB File: $GEOIPDB_FILE";
  GEOIPDB_CHECKSUM_FILE=$(curl -s -O -J -w '%{filename_effective}' "$GEOIPDB_CHECKSUM" | awk {'print $1'});
  #echo "GeoIP DB Checksum File: $GEOIPDB_CHECKSUM_FILE";
  echo "The Maxmind GeoLite2 IP DB and checksum files for $DBTYPE successfully downloaded..."  | ts '[%H:%M:%S]' | tee -a $LOGFILE;
else
  # Exit if file has not been updated
  echo "The Maxmind GeoLite2 IP Database file has not been updated.  Exiting..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  exit;
fi

# Compare downloaded file to checksum and start file processing
echo "Comparing sha256 checksum to verify file integrity before preoceeding..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
CHECKSUM=$(sha256sum -c $GEOIPDB_CHECKSUM_FILE | awk {'print $2'}) 
if [[ "$CHECKSUM" == "OK" ]]; then #convert and transfer file to ADC
   echo "The Maxmind GeoLite2 IP Database file checksum is verified. Unpacking archive for conversion..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   # Unzip the GeoLite2 IP DB
   unzip -j $GEOIPDB_FILE;
   echo "Unzipped $GEOIPDB_FILE..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   #Run the Citrix tool to convert the DB to NetScaler format
      if [ -f "$CONVERSION_TOOL" ]; then
         perl $CONVERSION_TOOL -b GeoLite2-$DBTYPE-Blocks-IPv4.csv -i GeoLite2-$DBTYPE-Blocks-IPv6.csv -l  GeoLite2-$DBTYPE-Locations-$LANGUAGE.csv -o Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -p Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -logfile $LOGFILE;
      echo "Successfully converted MaxMind GeoLite2 IP Database files to NetScaler format..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
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
   sshpass -p "$CITRIX_ADC_PASSWORD" scp Citrix_Netscaler_InBuilt_GeoIP_DB_IPv* $CITRIX_ADC_USER@$CITRIX_ADC_IP:$CITRIX_ADC_GEOIPDB_PATH;
   echo "Adding IPv4 and IPv6 GeoIP location files to ADC configuration for use in GSLB and PI..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   # Add the location db files (benign if already present in config)
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh $CITRIX_ADC_USER@$CITRIX_ADC_IP "add locationFile /var/netscaler/inbuilt_db/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -format netscaler";
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh $CITRIX_ADC_USER@$CITRIX_ADC_IP "add locationFile6 /var/netscaler/inbuilt_db/Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -format netscaler";
   # Save the ns.conf - this will also invoke the filesync process to synchronize the db files to ha peer nodes or cluster nodes (note - watchdog will also eventually do this)
   echo "Saving configuration and invoking filesync..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   sshpass -p "$CITRIX_ADC_PASSWORD" ssh $CITRIX_ADC_USER@$CITRIX_ADC_IP "save config"
else
  echo "The checksum failed.  File is corrupt or tampered with in transit..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  do_cleanup;
  exit 1;
fi

do_cleanup
exit 0
