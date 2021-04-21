#! /bin/bash -e

#Log output
exec > >(tee /var/log/Add-region-to-PAC.log|logger -t user-data -s 2>/dev/console) 2>&1

if [ "$#" -ne 1 ]
then
  echo "Not Enough Arguments supplied."
  echo "Add-region-to-PAC <RegionName>"
  exit 1
fi

RegionName=$1

# Logon to ESCWA
RequestURL='http://localhost:10004/logon'
Origin='Origin: http://localhost:10004'
Jmessage='{"mfUser":"","mfPassword":""}'
curl -sX POST $RequestURL -H 'accept: application/json' -H 'X-Requested-With: AgileDev' -H 'Content-Type: application/json' -H "$Origin" -d "$Jmessage" --cookie-jar cookie.txt

# Add PAC configuration to region
RequestURL="http://localhost:10004/native/v1/regions/127.0.0.1/86/${RegionName}"
echo $RequestURL
Jmessage='{"mfCASSOR":":ES_SCALE_OUT_REPOS_1=DemoPSOR=redis,ESRedis:6379##TMP","mfCASPAC":"DemoPAC"}'
curl -sX PUT $RequestURL -H 'accept: application/json' -H 'X-Requested-With: AgileDev' -H 'Content-Type: application/json' -H "$Origin" -d "$Jmessage" --cookie-jar cookie.txt
