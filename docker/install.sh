#!/bin/bash
#
# Docker install
# 
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/install.sh | bash
#

# commands detection
command -v apt-get > /dev/null && pkg_mgmt=apt
command -v yum > /dev/null && pkg_mgmt=yum
command -v systemctl > /dev/null && systemctl_cmd=1
command -v git > /dev/null || install_packages=1
command -v pip3 > /dev/null || install_packages=1
command -v docker > /dev/null || install_docker=1

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
                    python3-pip
            ;;

            yum)
                yum install -y \
                    git \
                    python3-pip
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
