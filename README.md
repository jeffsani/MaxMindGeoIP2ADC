# maxmindgeolite2adc

Initial version: 3/26/2022

This script will periodically download the maxmind the free Geolite2 City DB if it has been refreshed, perform a checksum on the file, convert it to the required format, and copy it to Citrix ADC on a weekly basis.  

To implement this script you will need the following:

1. a Geolite2 Account setup at https://www.maxmind.com/en/geolite2/signup?lang=en
2. a License Key - created post account setup and generated at https://www.maxmind.com/en/accounts/696069/license-key
3. Permalinks to the country/City DBs 
4. A host or container to run this on
5. This conversion tool https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format
