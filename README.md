# maxmindgeolite2adc

This script will periodically download the maxmind Geolite2 City DB and copy it to Citrix ADC on a weekly basis.  


To implement this script you will need the following:
1. a Geolite2 Account setup at https://www.maxmind.com/en/geolite2/signup?lang=en
2. a License Key - created post account setup and generated at https://www.maxmind.com/en/accounts/696069/license-key
3. a host to run this on - Linux or perhaps a docker container given this is not a huge function
4. Perl
5. This conversion tool https://github.com/citrix/MaxMind-GeoIP-Database-Conversion-Citrix-ADC-Format

