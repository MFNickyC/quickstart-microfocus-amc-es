#! /bin/bash -e

#Log output
exec > >(tee /var/log/Start-ESCWA.log|logger -t user-data -s 2>/dev/console) 2>&1

source /opt/microfocus/EnterpriseDeveloper/bin/cobsetenv

nohup escwa --BasicConfig.MfRequestedEndpoint="tcp:*:10086" --write=true < /dev/null > /tmp/escwa.out 2>&1 &

while ! curl http://localhost:10086
do
    sleep 1
done