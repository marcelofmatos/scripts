#!/bin/bash
#
# Docker Swarm Mode install
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/swarm/manager/install.sh | bash
# 

# commands detection
command -v apt-get > /dev/null && pkg_mgmt=apt
command -v yum > /dev/null && pkg_mgmt=yum
command -v systemctl > /dev/null && systemctl_cmd=1
command -v git > /dev/null || install_packages=1
command -v pip3 > /dev/null || install_packages=1
command -v docker > /dev/null || install_docker=1
command -v docker-compose > /dev/null || install_dockercompose=1

# to read your local .env file if exists and creating project as you wish
[ -f .env ] && . ./.env

# default values
installation_only=${installation_only:-0}

if [ $install_packages ]; then
    case "$pkg_mgmt" in
            apt)
                apt-get update
                apt-get install -y --no-install-recommends \
                    git \
                    python3-pip \
                    ncdu \
                    htop \
                    rsync \
                    vim
            ;;

            yum)
                yum install -y \
                    git \
                    python3-pip \
                    ncdu \
                    htop \
                    rsync \
                    vim \
                    screen
            ;;

            *)
                echo "Sorry! I did not detect the package manager for this system"
                echo "Could you help me? Check https://github.com/marcelofmatos/scripts/"
                exit 1;
            ;;
    esac
fi;

if [ "$install_docker" ]; then
    hostnamectl | grep 'Ubuntu' > /dev/null
    if [ $? -eq 0 ]; then
        apt install docker.io -y
    else 
        curl -fsSL https://get.docker.com | sh
    fi
    if [ $systemctl_cmd ]; then
        systemctl enable docker && systemctl start docker
    fi;
fi;

if [ "$install_dockercompose" ]; then
    case "$pkg_mgmt" in
        apt)
            apt-get update
            apt-get install -y --no-install-recommends \
                docker-compose \
                python3-setuptools
        ;;
        yum)
            yum install -y \
                docker-compose \
                python3-setuptools
        ;;
        *)
            echo "Fallback to pip installation for docker-compose"
            python3 -m pip config set global.break-system-packages true
            python3 -m pip config set global.no-build-isolation true
            python3 -m pip install --upgrade pip
            pip3 install setuptools
            pip3 install docker-compose
            # docker-compose link
            if [ -f /usr/local/bin/docker-compose ]; then
                ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            fi;
        ;;
    esac
fi;

export ADVERTISE_INTERFACE=${ADVERTISE_INTERFACE:-`ip -br a | grep -v 127.0 | head -n 1 | cut -f 1 -d " "`}
export ADVERTISE_IP=`ip -br a | grep $ADVERTISE_INTERFACE | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'`
export ADVERTISE_IP=${ADVERTISE_IP:-"server_ip"}
export PORTAINER_USERNAME=${PORTAINER_USERNAME:-"maint"}
export PORTAINER_PASSWORD=${PORTAINER_PASSWORD:-"ac@prtnr"}
export PROXY_NET=${PROXY_NET:-"proxy"}

echo "Docker Info"
docker info

echo "Docker Networks"
docker network ls

echo "Docker Swarm Init"
docker swarm init --advertise-addr ${ADVERTISE_INTERFACE}:2377 
docker swarm update --task-history-limit 1

echo "Docker Ingress network"
docker network create --driver=overlay $PROXY_NET

echo "Docker Volume Manager"
docker volume create manager 

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
