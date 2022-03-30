#!/bin/bash
# init.sh

# This script will setup your host for the geolite2adc script on a debian or ubuntu host with the apt package manager

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

echo 'export LICENSE_KEY="$LICENSE" 
export CITRIX_ADC_USER="$ADC_USER" 
export CITRIX_ADC_PASSWORD="$ADC_PASSWD" 
export CITRIX_ADC_IP="$NSIP"' >> ~/.bashrc
source ~/.bashrc
echo "Script variables set successfully..." | ts '[%H:%M:%S]' | tee -a $LOGFILE

# Download and install pre-requisites
echo "Installing required system pre-requisites..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
sudo apt-update
sudo apt install unzip libwww-perl libmime-lite-perl libnet-ip-perl git sshpass

# Clone git repo for NetScaler format conversion script in to same directory
echo "Checking for MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format repo..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
if [[ ! -d "./conversiontool" ]]; then
   echo "Repo not present - cloning from github..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
   git clone https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format.git ./conversiontool
else
   echo "Repo not present - cloning from github..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
fi

# Create cron job for scheduling the script to be run weekly on Wed at 1AM
echo "Removing cronjob if exists..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
crontab -u $(whoami) -l | grep -v '/home/$(whoami)/maxmindgeolite2adc/geolite2adc.sh' | crontab -u  $(whoami) -
echo "creating cron job to schedule script..." | ts '[%H:%M:%S]' | tee -a $LOGFILE
crontab -l > geolite2adc
echo "0 1 * * 3 $(pwd)/geolite2adc.sh" >> geolite2adc
crontab geolite2adc
rm geolite2adc

