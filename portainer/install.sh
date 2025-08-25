#!/bin/bash
#
# Portainer install
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/portainer/ | bash
# 

PORTAINER_USERNAME=${PORTAINER_USERNAME:-"admin"}
PORTAINER_PASSWORD=${PORTAINER_PASSWORD:-"portainer#12"}

echo "Portainer Configuration"
git clone https://github.com/marcelofmatos/portainer/ /var/lib/docker/volumes/manager/_data/portainer
bash /var/lib/docker/volumes/manager/_data/portainer/update.sh


while true; do 
    echo "Waiting portainer service"
    sleep 10
    curl -qsI localhost:9000 > /dev/null
    if [ "$?" == "0" ]; then break; fi
done

echo "Portainer started"

curl -X POST http://localhost:9000/api/users/admin/init \
  -H 'Content-Type: application/json' \
  -d "{ \"Username\": \"$PORTAINER_USERNAME\", \"Password\": \"$PORTAINER_PASSWORD\" }" > /dev/null

if [ "$?" == "0" ]; then 
  echo "Access: http://$ADVERTISE_IP:9000"
  echo "Username: $PORTAINER_USERNAME"
  echo "Password: $PORTAINER_PASSWORD" 
fi
