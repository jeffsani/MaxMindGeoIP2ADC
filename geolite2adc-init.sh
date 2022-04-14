#!/bin/bash
# geolite2adc-init.sh
# This script will setup your host for the geolite2adc script on a debian or fedora/centos based host

set -o pipefail

# Fix perl locale issue
#echo "export LANGUAGE=en_US.UTF-8 
#export LANG=en_US.UTF-8 
#export LC_ALL=en_US.UTF-8">>~/.bashrc

# Create init logfile
LOGFILE="$(date '+%m%d%Y')-maxmindgeolite2adc-init.log"

# Prompt for and set rc variables 
echo "Setting script variables..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
echo "Enter your Maxmind License Key:"
read LICENSE
echo "Enter the Citrix ADC user for the script:"
read ADC_USER
echo "Enter the Citrix ADC user password:"
read ADC_PASSWD
echo "Enter your Citrix ADC NSIP:"
read NSIP
echo "Enter your Citrix ADC NSIP Port:"
read NSIP_PORT

if [[ -z "${LICENSE_KEY}" || -z "${CITRIX_ADC_USER}" || -z "${CITRIX_ADC_PASSWORD}" || -z "${CITRIX_ADC_IP}" || -z "${CITRIX_ADC_PORT}" ]]; then
cat >>~/.bashrc <<-EOF
   #Start-geolite2adc
   export LICENSE_KEY="$LICENSE"
   export CITRIX_ADC_USER="$ADC_USER"
   export CITRIX_ADC_PASSWORD="$ADC_PASSWD"
   export CITRIX_ADC_IP="$NSIP"
   export CITRIX_ADC_PORT="$NSIP_PORT"
   #End-geolite2adc
EOF
   source ~/.bashrc;
   echo "Script variables set successfully..." | ts '[%H:%M:%S]' | tee -a $LOGFILE;
else
   sed -i -e 's/LICENSE_KEY=.*/LICENSE_KEY=$LICENSE/' -e 's/CITRIX_ADC_USER=.*/CITRIX_ADC_USER=$ADC_USER/' -e 's/CITRIX_ADC_PASSWORD=.*/CITRIX_ADC_PASSWORD=$ADC_PASSWD/' -e 's/CITRIX_ADC_IP=.*/CITRIX_ADC_IP=$NSIP/' ~/.bashrc
fi

# Download and install pre-requisites
echo "Installing required system pre-requisites..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
which yum >/dev/null && {yum install unzip perl-libwww-perl perl-MIME-Lite perl-Net-IP perl-Time-Piece sshpass more-utils}
which apt-get >/dev/null && {apt install unzip libwww-perl libmime-lite-perl libnet-ip-perl sshpass moreutils}

# Download NetScaler format conversion script in to same directory
echo "Checking for MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format repo..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
if [[ ! -e "./Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl" ]]; then
   echo "Conversion tool not present - downloading from github..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   curl -s -O -J https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format/blob/master/Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl
else
   echo "Conversion tool already present - skipping download..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
fi

# Check known_hosts file for presence of NSIP and add if not present
if [ $NSIP_PORT -eq "22" ]; then
   ssh-keygen -F $NSIP -f ~/.ssh/known_hosts &>/dev/null;
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      ssh-keyscan $NSIP >> ~/.ssh/known_hosts;
   fi
else 
   ssh-keygen -F '[$NSIP]:$NSIP_PORT' -f ~/.ssh/known_hosts &>/dev/null;
   if [ "$?" -ne "0" ]; then 
      # Add ADC to known_hosts
      ssh-keyscan -p $NSIP_PORT $NSIP >> ~/.ssh/known_hosts;
   fi
fi

# Create cron job for scheduling the script to be run weekly on Wed at 1AM
echo "Removing cronjob if exists..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
crontab -u $(whoami) -l | grep -v '/home/$(whoami)/maxmindgeolite2adc/geolite2adc.sh' | crontab -u  $(whoami) -
echo "creating cron job to schedule script..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
crontab -l > geolite2adc
echo "0 1 * * 3 $(pwd)/geolite2adc.sh" >> geolite2adc
crontab geolite2adc
rm geolite2adc