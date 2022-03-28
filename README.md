# maxmindgeolite2adc

Initial version: 3/26/2022

This script will automate the refresh of the InBuilt MaxMind GeoLite2 Location DB files Citrix_Netscaler_InBuilt_GeoIP_DB_IPv4 and Citrix_Netscaler_InBuilt_GeoIP_DB_IPv6 for use with Static Proximity GSLB and Policy Expressions that reference a Location.  The main benefit of this is that these file are not updated through upgrades.  The script will run weekly, download the maxmind the free Geolite2 City or Country DB if it has been refreshed, perform a checksum on the file, convert it to the required NetScaler format, and upload the requisite directory where the InBuilt files are located to refresh them. 

To implement this script you will need the following:

1. a Geolite2 Account setup at https://www.maxmind.com/en/geolite2/signup?lang=en
2. a License Key - created post account setup and generated at https://www.maxmind.com/en/accounts/696069/license-key
3. Permalinks to the country/City DBs 
4. A host or container to run this on
5. This conversion tool https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format
6. unzip utility


Required Packages
- unzip
- libwww-perl libmime-lite-perl libnet-ip-perl
