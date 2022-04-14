# maxmindgeolite2adc

Initial version: 1.0
Date: 3/29/2022
Author: Jeff Sani

<strong>Description:</strong></br>
This script will automate the refresh of the Citrix ADC (NetScaler) InBuilt MaxMind GeoLite2 Location Database files Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 and Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 which are used with Static Proximity GSLB and Policy Expressions that reference a Location.  See https://docs.citrix.com/en-us/citrix-adc/current-release/global-server-load-balancing/configuring-static-proximity.html for more information about GSLB Static Proximity.  The main benefit of this script is to refresh these location files with up-to-date versions as these are not updated via on-box automation or new firmware installs.  The script will run weekly, download the maxmind free Geolite2 City or Country DB (CSV Format) if it has been refreshed, perform a checksum on the file to verify file integrity, convert it to the required NetScaler location db format, and upload the new files to the requisite directory where the InBuilt files are located. The InBuilt files will get automatically synchronized across HA pair or Cluster nodes.

According to the maxmind web site, the GeoIP Databases are updated each Tuesday - see https://support.maxmind.com/hc/en-us/articles/4408216129947-Download-and-Update-Databases.  Thus, the init script configures a cron job which is scheduled to run every Wednesday morning at 1:00AM to perform the update.  

<strong>Automated Setup Steps (For Linux Host):</strong></br>

<ol type="1">
   <li>Login to your host as the user you want to create the script under</li>
   <li>su to root or another priviledged account for the package install - i.e. su root /bin/bash
   <li>Complete steps 2-4 in the requirements below for access to the Maxmind GeoLite2 IP databases</li>
   <li>Clone the repo into the desired directory on your linux host:</li>
      <ul><li>git clone https://github.com/jeffsani/maxmindgeolite2adc.git <directory> (directory is optional)</li></ul>
   <li>cd to that directory</li>
   <li>Run the geolite2adc-init.sh script</li>
</ol>
 
<strong>Script Requirements:</strong></br>

To implement this script you will need the following if you plan to implement manually and not use the init script:

<ol type="1">
   <li>A host or container to run this on</li>
   <li>A Geolite2 Account setup at https://www.maxmind.com/en/geolite2/signup?lang=en</li>
   <li>An API License Key - created post account setup (step 1)</li>
   <li>Permalinks to the Country and/or City Geo IP Databases in CSV format </li>
   <li>Required Packages:</li>
       <ul>
          <li>Ubuntu: unzip libwww-perl libmime-lite-perl libnet-ip-perl git unzip sshpass moreutils</li>
          <li>CentOS/Fedora: unzip perl-libwww-perl perl-MIME-Lite perl-Net-IP perl-Time-Piece sshpass more-utils</li>
       </ul>
   <li>This conversion tool https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format</li>
   <li>Environment variables set for the user running the script that contain the Citrix ADC user/pass, and the Citrix ADC IP/Port as per below</li>
   <li>cron job to schedule the script to run every Wed morning to check for IP DB updates</li>
</ol>

<strong>Required Environment Variables:</strong></br>

<ul>
   <li>LICENSE_KEY=XXXX
   <li>CITRIX_ADC_USER=XXX
   <li>CITRIX_ADC_PASSWORD=XXX
   <li>CITRIX_ADC_IP=X.X.X.X
   <li>CITRIX_ADC_PORT=NNN
</ul>
