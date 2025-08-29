#!/bin/bash

/usr/bin/tar cvzf "/home/ubuntu/swarm-${ENGINE}-$(hostname -s)-$(date +%s%z).tgz" /var/lib/docker/swarm/



# backup for configs and secrets
# ref. https://github.com/softonic/swarm-backup-restore
