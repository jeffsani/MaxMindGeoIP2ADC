# MaxMindGeoIP2ADC
Author: Jeff Sani</br>
Contributors: Matt Drown, Chuck Cox</br>
Version: 1.0</br>
Last Update: 5/27/2022</br>

<img src="mmgeoip2adc.png" style="display:block; margin-left: auto; margin-right: auto;">
<strong>Description</strong></br>
Accurate IP location information is important if you are using this as a factor for device posture or for geofencing applications and APIs.  This script will automate the refresh of the Citrix ADC (NetScaler) InBuilt MaxMind Location Database files Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 and Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 which are used with Static Proximity GSLB and Policy Expressions that reference a Location.  See <a href="https://docs.citrix.com/en-us/citrix-adc/current-release/global-server-load-balancing/configuring-static-proximity.html">Citrix GSLB Documentation</a> for more information about GSLB Static Proximity.  The default InBuilt IP DB files are based on the GeoLite2 free edition which is also the default for this script, but MaxMind also has a Enterprise version (GeoIP2) which is  more precise, contains additional information, and is updated more frequently. For more information about the MaxMind GeoLite2 and GeoIP Geolocation databases and their limits, accuracy, etc... visit the <a href="https://dev.maxmind.com/geoip/geolite2-free-geolocation-data?lang=en">GeoLite2</a> and <a href="https://www.maxmind.com/en/solutions/geoip2-enterprise-product-suite/enterprise-database">GeoIP2</a> product pages</a>. This script supports both versions by setting the "EDITION" variable.<p>

The main benefit of this script is to keep the location files up-to-date as these are not updated via on-box automation or new firmware installs.  At the time of writing, the InBuilt files were last updated in 2019.  According to the MaxMind support knowledge base, the GeoLite2 IP Databases are updated each Tuesday and the GeoIP2 IP Databases are updated every Tuesday and Friday - Please refer to the <a href="https://support.maxmind.com/hc/en-us/articles/4408216129947-Download-and-Update-Databases">Database Update KB article</a> for more details.  Based on this, the init script configures a cron job which is scheduled to run every Wednesday morning at 1:00AM to perform the update of the GeoLite2 IP Database and every Wednesday and Saturday morning at 1:00AM for the GeoIP2 IP Database version. The script will download the MaxMind City or Country DB (CSV Format) if it has been refreshed, perform a checksum on the file to verify file integrity, convert it to the required NetScaler location db format, upload the new files to the requisite directory where the InBuilt files are located, create static ip databse entries for IPv4 and IPv6, and save the configuration. The InBuilt files will get automatically synchronized across HA pair or Cluster nodes.<p>

<strong>Automated Setup Steps (For CentOS/Fedora or Ubuntu Linux Host)</strong></br>
<ol type="1">
   <li>Login to your host as the user you want to create the script under</li>
   <li>Install the required Linux packages or follow this prompt in the init script</li>
   <li>Complete steps 3-5 in the requirements below for access to the MaxMind GeoLite2 or GeoIP2 databases</li>
   <li>Clone the repo into the desired directory on your linux host:</li>
      <ul><li>git clone https://github.com/jeffsani/MaxMindGeoIP2ADC.git</li></ul>
   <li>cd to MaxMindGeoIP2ADC</li>
   <li>Run the mmgeoip2adc-init.sh script</li>
</ol>
 
<strong>Script Requirements</strong></br>
To implement this script you will need the following if you plan to implement manually and not use the init script:
<ol type="1">
   <li>A Linux host or container to run this on</li>
   <li>Citrix ADC Build Version 12.1, 13.0, or 13.1 (It may work on older builds as well but I did not test those and they are EOL)</li>
   <li>A <a href="https://www.maxmind.com/en/geolite2/signup?lang=en">GeoLite2</a> account or GeoIP2 Enterprise account </li>
   <li>An API License Key - created post account setup in the MaxMind portal</li>
   <li>Permalinks to the Country and/or City Geo IP Databases in CSV format - obtained on the downloads page within your account</li>
   <li>Required Linux Packages:</li>
       <ul>
          <li>Debian/Ubuntu: curl unzip libwww-perl libmime-lite-perl libnet-ip-perl git sshpass moreutils</li>
          <li>CentOS/Fedora: curl unzip perl-libwww-perl perl-MIME-Lite perl-Net-IP perl-Time-Piece git sshpass more-utils</li>
       </ul>
   <li>The <a href ="https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format">Citrix ADC GSLB GeoIP Conversion Tool</a></li>
   <li>Environment variables set for the user running the script that contain the MaxMind and Citrix ADC details as per below</li>
   <li>cron job to schedule the script to check for IP DB updates</li>
</ol>

<strong>Required Environment Variables</strong></br>
The following variables and their respective values are required at script runtime so it is suggested they be stored in .bashrc and or .bash_profile or a local configuration file
<ul>
   <li>LICENSE_KEY=XXXX</li>
   <li>EDITION=[GeoLite2 or GeoIP2]</li>
   <li>CITRIX_ADC_USER=XXX</li>
   <li>CITRIX_ADC_PASSWORD=XXX</li>
   <li>CITRIX_ADC_IP=X.X.X.X</li>
   <li>CITRIX_ADC_PORT=NNN</li>
</ul>

<strong>Script Usage</strong></br>
If you want to override the freshness check for the databases, you can use the -f flag when running the script:

<code>#./mmgeoip2adc.sh -f</code>

<strong>ADC Service Account and Command Policy</strong></br>
It is optional but recommended to create a service account on ADC to use for the purposes of running this script in lieu of just using nsroot:  

<code>add system cmdPolicy geoip2adc_cmdpol ALLOW "((^(scp).\*/var/netscaler/inbuilt_db\*)|(^save\\s+ns\\s+config)|(^save\\s+ns\\s+config\\s+.\*)|(^add\\s+(locationFile|locationFile6))|(^add\\s+(locationFile|locationFile6)\\s+.\*))"
</code></br>
<code>add system user geoip2adc -timeout 900 -maxsession 2 -allowedManagementInterface CLI</code></br>
<code>bind system user geoip2adc geoip2adc_cmdpol 100</code>
