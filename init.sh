#This script will setup your host for the geolite2adc script

#fix perl locale issue
echo "export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8">>~/.bash_profile

#download and install pre-requisites
apt install unzip libwww-perl libmime-lite-perl libnet-ip-perl

#clone git repo for NetScaler format conversion script

#create cron job for scheduling the script to be run weekly


