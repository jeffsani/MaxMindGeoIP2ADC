#!/bin/bash
# init.sh

# This script will setup your host for the geolite2adc script on a debian or ubuntu host with the apt package manager

# Fix perl locale issue
#echo "export LANGUAGE=en_US.UTF-8 
#export LANG=en_US.UTF-8 
#export LC_ALL=en_US.UTF-8">>~/.bashrc

# Prompt for and set rc variables 
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

# Download and install pre-requisites
sudo apt-update
sudo apt install unzip libwww-perl libmime-lite-perl libnet-ip-perl git sshpass

# Clone git repo for NetScaler format conversion script in to same directory
if [[ ! -d "./conversiontool" ]]; then
   git clone https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format.git ./conversiontool
fi

# Create cron job for scheduling the script to be run weekly on Wed at 1AM
crontab -l > geolite2adc
echo "0 1 * * 3 $(pwd)/geolite2adc.sh" >> geolite2adc
crontab geolite2adc
rm geolite2adc

