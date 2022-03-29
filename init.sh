#!/bin/bash
# init.sh

# This script will setup your host for the geolite2adc script on a debian or ubuntu host with the apt package manager

# Fix perl locale issue
echo "export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8">>~/.bash_profile

# Download and install pre-requisites
sudo apt-update
sudo apt install unzip libwww-perl libmime-lite-perl libnet-ip-perl git

# clone git repo for NetScaler format conversion script in to same directory
git clone https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format.git ./conversiontool

# Create cron job for scheduling the script to be run weekly


