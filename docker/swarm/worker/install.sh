#!/bin/bash
#
# Docker Swarm Mode install
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/swarm/worker/install.sh | bash
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
                echo "Could you help us? Check https://github.com/marcelofmatos/scripts"
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

## Kernel config
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' > /etc/sysctl.d/elasticsearch.conf
sysctl -w vm.overcommit_memory=1
echo 'vm.overcommit_memory=1' > /etc/sysctl.d/redis.conf

# swap config
cp /etc/fstab /etc/fstab.bkp
install -o root -g root -m 0600 /dev/null /swapfile1
dd if=/dev/zero of=/swapfile1 bs=1k count=4096k
mkswap /swapfile1
swapon /swapfile1
echo '/swapfile1          none                  swap    defaults        0 0' >> /etc/fstab
mount -a
free -m

echo "Docker Info"
docker info

echo "Docker Swarm"
echo "Run command above on manager server to join this machine to cluster:"
echo "  docker swarm join-token worker"
