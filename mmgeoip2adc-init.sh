#!/bin/bash
# mmgeoip2adc-init.sh
# This script will setup your host for the mmgeoip2adc script on a debian or fedora/centos based host

set -o pipefail

# Create init logfile
LOGFILE="$(date '+%m%d%Y')-mmgeoip2adc-init.log"

# Prompt for and set rc variables 
echo "Setting script variables in ~/.bashrc..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
echo "Enter your MaxMind License Key:"
read LICENSE
echo "Enter your MaxMind Edition (GeoLite2 or GeoIP2):"
read LICENSE_EDITION
echo "Enter the Citrix ADC user for the script:"
read ADC_USER
echo "Enter the Citrix ADC user password:"
read ADC_PASSWD
echo "Enter your Citrix ADC NSIP:"
read NSIP
echo "Enter your Citrix ADC NSIP Port:"
read NSIP_PORT

if grep -q "#Start-mmgeoip2adc" ~/.bashrc; then
   sed -i -e "s/LICENSE_KEY=.*/LICENSE_KEY=$LICENSE/" -e "s/EDITION=.*/EDITION=$LICENSE_EDITION/" -e "s/CITRIX_ADC_USER=.*/CITRIX_ADC_USER=$ADC_USER/" -e "s/CITRIX_ADC_PASSWORD=.*/CITRIX_ADC_PASSWORD=$ADC_PASSWD/" -e "s/CITRIX_ADC_IP=.*/CITRIX_ADC_IP=$NSIP/" -e "s/CITRIX_ADC_PORT=.*/CITRIX_ADC_PORT=$NSIP_PORT/" ~/.bashrc
else
cat >>~/.bashrc <<-EOF
#Start-NetScaler-Vars
export LICENSE_KEY="$LICENSE"
export EDITION="$LICENSE_EDITION"
export CITRIX_ADC_USER="$ADC_USER"
export CITRIX_ADC_PASSWORD="$ADC_PASSWD"
export CITRIX_ADC_IP="$NSIP"
export CITRIX_ADC_PORT="$NSIP_PORT"
#End-NetScaler-Vars
EOF
fi
echo "Script variables set successfully..." | ts '[%H:%M:%S]' | tee -a $LOGFILE

# Download and install pre-requisites
echo "Do you want to install required system pre-requisites (requires elevated privs or sudoer membership) Y/N?..."
read ANSWER1
ANSWER1=${ANSWER1,,} # convert to lowercase
if [ "$ANSWER1" == "y" ]; then
   echo "Installing required system pre-requisites..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   which sudo yum >/dev/null && { sudo yum install curl unzip perl-libwww-perl perl-MIME-Lite perl-Net-IP perl-Time-Piece sshpass more-utils; }
   which sudo apt-get >/dev/null && { sudo apt install curl unzip libwww-perl libmime-lite-perl libnet-ip-perl sshpass moreutils; }
else
   echo "Skipping install of required system pre-requisites..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   echo "Please refer to Readme for script requirements..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
fi

# Download NetScaler format conversion script in to same directory
echo "Checking for MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format repo..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
if [[ ! -e "./Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl" ]]; then
   echo "Conversion tool not present - downloading from github..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   curl -s -O -J https://raw.githubusercontent.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format/master/Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl
else
   echo "Conversion tool already present - skipping download..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
fi

# Check known_hosts file and presence of NSIP and add if not present
if [ ! -r ~/.ssh/known_hosts ]; then mkdir -p ~/.ssh; touch ~/.ssh/known_hosts; fi
if [ $NSIP_PORT -eq "22" ]; then
   ssh-keygen -F $NSIP -f ~/.ssh/known_hosts &>/dev/null
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      echo "Adding ADC IP $NSIP to known_hosts..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
      ssh-keyscan $NSIP >> ~/.ssh/known_hosts 2> /dev/null
   else
      echo "ADC IP already present in known_hosts - Skipping add..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   fi
else 
   ssh-keygen -F '[$NSIP]:$NSIP_PORT' -f ~/.ssh/known_hosts &>/dev/null
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      echo "Adding ADC IP $NSIP to known_hosts..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
      ssh-keyscan -p $NSIP_PORT $NSIP >> ~/.ssh/known_hosts  2> /dev/null
   else
      echo "ADC IP $NSIP already present in known_hosts - Skipping add..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   fi
fi

# Create cron job for scheduling the script to be run weekly on Wed at 1AM
echo "Removing old cron job if it exists..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
crontab -l | grep -v "mmgeoip2adc.sh" | crontab -
echo "Creating new cron job..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
if [[ $LICENSE_EDITION == "GeoLite2" ]]; then
   echo "0 1 * * 3 $(pwd)/mmgeoip2adc.sh" >> mmgeoip2adc
else
   echo "0 1 * * 3,6 $(pwd)/mmgeoip2adc.sh" >> mmgeoip2adc
fi
crontab mmgeoip2adc
rm mmgeoip2adc

echo "All done!..." | ts '[%H:%M:%S]' | tee -a $LOGFILE