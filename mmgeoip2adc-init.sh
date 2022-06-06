#!/bin/bash
# mmgeoip2adc-init.sh
# This script will setup your host for the mmgeoip2adc script on a debian or fedora/centos based host

set -o pipefail

# Set local variables
LOGFILE="./log/$(date '+%m%d%Y')-mmgeoip2adc-init.log"
NSC2E_CONF=~/.adcrc

(
# Create log directory and conf if they do not already exist
echo "checking for log directory and configuration file and creating if not present..."
[ ! -d "./log" ] && mkdir log; [ ! -f "$NSC2E_CONF" ] && touch $NSC2E_CONF

# Prompt for and set  variables 
echo "Setting script variables..."
echo "Enter your MaxMind License Key: "; read LICENSE
echo "Enter your MaxMind Edition [GeoLite2 or GeoIP2]: "; read LICENSE_EDITION
echo "Enter the Citrix ADC user for the script: "; read ADC_USER
echo "Enter the Citrix ADC user password: "; read -s ADC_PASSWD
echo "Enter your Citrix ADC NSIP: "; read NSIP
echo "Enter your Citrix ADC NSIP Port: "; read NSIP_PORT

# Load common variables from conf and check vars to see if one of the required environment variables is not set
. $NSC2E_CONF

if [[ ! -z "$LICENSE_KEY" && ! -z "EDITION" && ! -z "$MMGEOIP2ADC_ADC_USER" && ! -z "$MMGEOIP2ADC_ADC_PASSWORD" && ! -z "$MMGEOIP2ADC_ADC_IP" && ! -z "$MMGEOIP2ADC_ADC_PORT" ]]; then
   echo "Exisitng variables detected - refreshing values..."
   sed -i -e "s/LICENSE_KEY=.*/LICENSE_KEY=$LICENSE/" -e "s/EDITION=.*/EDITION=$LICENSE_EDITION/" -e "s/MMGEOIP2ADC_ADC_USER=.*/MMGEOIP2ADC_ADC_USER=$ADC_USER/" -e "s/MMGEOIP2ADC_ADC_PASSWORD=.*/MMGEOIP2ADC_ADC_PASSWORD=\'$ADC_PASSWD\'/" -e "s/MMGEOIP2ADC_ADC_IP=.*/MMGEOIP2ADC_ADC_IP=$NSIP/" -e "s/MMGEOIP2ADC_ADC_PORT=.*/MMGEOIP2ADC_ADC_PORT=$NSIP_PORT/" $NSC2E_CONF
else
cat >>$NSC2E_CONF <<-EOF
#Start-mmgeoip2adc-Vars
export LICENSE_KEY="$LICENSE"
export EDITION="$LICENSE_EDITION"
export MMGEOIP2ADC_ADC_USER="$ADC_USER"
export MMGEOIP2ADC_ADC_PASSWORD='$ADC_PASSWD'
export MMGEOIP2ADC_ADC_IP="$NSIP"
export MMGEOIP2ADC_ADC_PORT="$NSIP_PORT"
#End-mmgeoip2adc-Vars
EOF
fi
echo "Script variables set successfully..."

# Download and install pre-requisites
echo "Do you want to install required system pre-requisites (requires elevated privs or sudoer membership) [Y/n]?..."; read ANSWER1
ANSWER1=${ANSWER1,,} # convert to lowercase
if [ "$ANSWER1" == "y" ]; then
   echo "Installing required system pre-requisites..."
   which sudo yum >/dev/null && { sudo yum install curl unzip perl-libwww-perl perl-MIME-Lite perl-Net-IP perl-Time-Piece sshpass more-utils; }
   which sudo apt-get >/dev/null && { sudo apt install curl unzip libwww-perl libmime-lite-perl libnet-ip-perl sshpass moreutils; }
else
   echo "Skipping install of required system pre-requisites..."
   echo "Please refer to Readme for script requirements..."
fi

# Download NetScaler format conversion script in to same directory
echo "Checking for MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format repo..."
if [[ ! -e "./Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl" ]]; then
   echo "Conversion tool not present - downloading from github..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   curl -s -O -J https://raw.githubusercontent.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format/master/Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl
else
   echo "Conversion tool already present - skipping download..."
fi

# Check known_hosts file and presence of NSIP and add if not present
echo "Checking for presence of $NSIP in ~/.ssh/known_hosts..."
if [ ! -r ~/.ssh/known_hosts ]; then mkdir -p ~/.ssh; touch ~/.ssh/known_hosts; fi
if [ $NSIP_PORT -eq "22" ]; then
   ssh-keygen -F $NSIP -f ~/.ssh/known_hosts &>/dev/null
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      echo "Adding ADC IP $NSIP not present in known_hosts - Adding IP..."
      ssh-keyscan $NSIP >> ~/.ssh/known_hosts 2> /dev/null
   else
      echo "ADC IP $NSIP already present in known_hosts - Skipping add..."
   fi
else 
   ssh-keygen -F '[$NSIP]:$NSIP_PORT' -f ~/.ssh/known_hosts &>/dev/null
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      echo "Adding ADC IP $NSIP not present in known_hosts - Adding IP..."
      ssh-keyscan -p $NSIP_PORT $NSIP >> ~/.ssh/known_hosts 2> /dev/null
   else
      echo "ADC IP $NSIP already present in known_hosts - Skipping add..."
   fi
fi

# Create cron job for scheduling the script to be run weekly on Wed at 1AM
echo "Removing old cron job if it exists..."
crontab -l | grep -v "mmgeoip2adc.sh" | crontab -
echo "Backing up existing entries..."
crontab -l > mmgeoip2adc
echo "Creating new cron job..."
LICENSE_EDITION=${LICENSE_EDITION,,} # convert to lowercase
if [[ $LICENSE_EDITION == "geolite2" ]]; then
   echo "0 1 * * 3 $(pwd)/mmgeoip2adc.sh" >> mmgeoip2adc
else
   echo "0 1 * * 3,6 $(pwd)/mmgeoip2adc.sh" >> mmgeoip2adc
fi
crontab mmgeoip2adc
rm mmgeoip2adc
echo "Successfully created new cron job..."

echo "All done!..."
>> $LOGFILE) 2>&1 | ts '[%H:%M:%S]' | tee -a $LOGFILE