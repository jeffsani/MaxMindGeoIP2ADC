#!/bin/bash
# geolite2adc.sh

#set -e
set -u
set -o pipefail
set -x

# Variables to put into environment variables rather than leaving in the script
LICENSE_KEY="141nr9qnsbEnkATO"
CITRIX_ADC_USER="nsroot"
CITRIX_ADC_PASSWORD="Marigold"
CITRIX_ADC_IP=10.0.0.105

# Local Variables
DBTYPE="Country" #Choose Country or City
LANGUAGE="en" #en, de, fr, es, jp, pt-BR, ru, or zh"
LOGFILE="$(date '+%m%d%Y')-Convert_GeoIPDB_To_Netscaler_Format.log"
CONVERSTION_TOOL_PATH="./conversiontool/perl Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl"

# Constants
CITRIX_ADC_GEOIP_PATH="/var/netscaler/inbuilt_db"

# Initiate Log
echo "User $(whoami) started the script" | ts '[%H:%M:%S]' | tee -a $LOGFILE
echo "Citrix ADC Letsencrypt Certificate Automation Log" | ts '[%H:%M:%S]' | tee -a $LOGFILE

# Check to see if one of the required environment variables for the script is not set
if [[ -z "${LICENSE_KEY}" || -z "${CITRIX_ADC_USER}" || -z "${CITRIX_ADC_PASSWORD}" ]]; then
    echo "One of the required environment variable for the script is not set" | ts '[%H:%M:%S]' | tee -a $LOGFILE;
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
  curl -s "$GEOIPDB_URL" -o GeoLite2-$DBTYPE-CSV.zip;
  curl -s "$GEOIPDB_CHECKSUM" -o GeoLite2-$DBTYPE-CSV.zip.sha256;
  echo "The Maxmind GeoLite2 IP DB and checksum files for $DBTYPE successfully downloaded..."  | ts '[%H:%M:%S]' | tee -a $LOGFILE;
else
  # Exit if file has not been updated
  echo "The Maxmind GeoLite2 IP Database file has not been updated.  Exiting..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  exit;
fi

# Compare downloaded file to checksum
echo "Comparing sha256 checksum to verify file integrity before preoceeding..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
CHECKSUM=$(sha256sum - c GeoLite2-$DBTYPE-CSV.zip.sha256)
if [[ "$CEHCKSUM" -eq "OK" ]]; then #convert and transfer file to ADC
   echo "The Maxmind GeoLite2 IP Database file checksum is verified. Unpacking archive for conversion..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   # Unzip the GeoLite2 IP DB
   unzip -j GeoLite2-$DBTYPE-CSV.zip;
   echo "Unzipped $GeoLite2-$DBTYPE-CSV.zip.sha256" | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   #Run the Citrix tool to convert the DB to NetScaler format
      if [ -f "$CONVERSTION_TOOL_PATH" ]; then
      ./conversiontool/perl Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl -b GeoLite2-$DBTYPE-Blocks-IPv4.csv -i GeoLite2-$DBTYPE-Blocks-IPv6.csv -l  GeoLite2-$DBTYPE-Locations-$LANGUAGE.csv -o Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 -p Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 -logfile $LOGFILE;
      echo "Successfully converted MaxMind GeoLite2 IP Database files to NetScaler format..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   else 
      echo "The Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl was not present, please refer to the README.md for the script requirements - Exiting..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
      do_cleanup;
      exit 1;
   fi
   # Unzip converted files
   echo "Preparing files for transfer to ADCs..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
   gunzip Citrix_Netscaler_InBuilt_GeoIP_DB*;
   # Convert Certs and Keys to Base 64 for API
   Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4_B64=$(cat "Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4" | base64 -w0);
   Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6_B64=$(cat "Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6" | base64 -w0);
   # Copy the files to the ADCS
   curl -s -k -X POST -H "Accept: application/json" -H "Content-Type: application/vnd.com.citrix.netscaler.systemfile+json" -H "Authorization: Basic $(echo -n ${CITRIX_ADC_USER}:${CITRIX_ADC_PASSWORD} | base64)" "https://${ADC_IP}/nitro/v1/config/systemfile" -d '{"systemfile":{"filename":"Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4","filelocation":"${CITRIX_ADC_GEOIP_PATH}","filecontent":"${Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4_B64}","fileencoding":"BASE64"}}';
   curl -s -k -X POST -H "Accept: application/json" -H "Content-Type: application/vnd.com.citrix.netscaler.systemfile+json" -H "Authorization: Basic $(echo -n ${CITRIX_ADC_USER}:${CITRIX_ADC_PASSWORD} | base64)" "https://${ADC_IP}/nitro/v1/config/systemfile" -d '{"systemfile":{"filename":"Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6","filelocation":"${CITRIX_ADC_GEOIP_PATH}","filecontent":"${Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6_B64}","fileencoding":"BASE64"}}';
   echo "Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 and Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 transferred to ADC with IP $ADC_IP" | ts '[%H:%M:%S]' | tee -a $LOGFILE;
else
  echo "The checksum failed.  File is corrupt or tampered with in transit..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
  do_cleanup;
  exit 1;
fi

# Do Cleanup
function do_cleanup {
echo "Cleaning up disposable files..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
rm -f *.csv* *.txt *.zip
}

exit 0
