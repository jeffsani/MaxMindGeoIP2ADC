# maxmindgeolite2adc

Initial version: 1.0
Date: 3/29/2022
Author: Jeff Sani

Description:
This script will automate the refresh of the Citrix ADC (NetScaler) InBuilt MaxMind GeoLite2 Location Database files Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 and Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 which are used with Static Proximity GSLB and Policy Expressions that reference a Location.  See https://docs.citrix.com/en-us/citrix-adc/current-release/global-server-load-balancing/configuring-static-proximity.html for more information about GSLB Static Proximity.  The main benefit of this script is to refresh these location files with up-to-date versions as these are not updated via on-box automation or new firmware installs.  The script will run weekly, download the maxmind free Geolite2 City or Country DB (CSV Format) if it has been refreshed, perform a checksum on the file to verify file integrity, convert it to the required NetScaler location db format, and upload the new files to the requisite directory where the InBuilt files are located. The InBuilt files will get automatically synchronized across HA pair or Cluster nodes.

According to the maxmind web site, the GeoIP Databases are updated each Tuesday - see https://support.maxmind.com/hc/en-us/articles/4408216129947-Download-and-Update-Databases.  Thus, the init script configures a cron job which is scheduled to run every Wednesday morning at 1:00AM to perform the update.  

Script Requirements:
To implement this script you will need the following:

1. A Geolite2 Account setup at https://www.maxmind.com/en/geolite2/signup?lang=en
2. An API License Key - created post account setup (step 1)
3. Permalinks to the Country and/or City Geo IP Databases in CSV format 
4. A host or container to run this on
5. This conversion tool https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format
6. Environment variables set for the user running the script that contain the Citrix ADC user/pass, and the Citrix ADC IP

Required Packages (for Host):
- unzip libwww-perl libmime-lite-perl libnet-ip-perl git unzip sshpass moreutils

Required Environment Variables:
LICENSE_KEY=XXXX
CITRIX_ADC_USER=XXX
CITRIX_ADC_PASSWORD=XXX
CITRIX_ADC_IP=X.X.X.X

Automated Setup (For Linux Host):
- Login to your host as the user you want to create the script under
- Complete steps 1-3 in the requirements
- Clone the repo into the desired directory on your linux host:
    git clone https://github.com/jeffsani/maxmindgeolite2adc.git <directory> (directory is optional)
- cd to that directory
- Run the geolite2adc-init.sh script
