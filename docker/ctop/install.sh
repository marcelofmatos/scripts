#!/bin/bash
#
# ctop install
#
# curl https://raw.githubusercontent.com/marcelofmatos/scripts/main/docker/ctop/install.sh | bash

curl -Lo /usr/local/bin/ctop https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-amd64
chmod +x /usr/local/bin/ctop