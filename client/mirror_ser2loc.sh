#!/bin/bash
if [ $# -eq 1 ]
 then 
 echo 'usage mirror_ser2loc.sh <localdirpath> /home/carrierc/<remotedirpath>
 exit 1;
fi
PASSWORD="carr1erc13"
SERVER="carrierconnections.net"
LOCAL_MIRROR=$1
REMOTE_MIRROR=$2/

lftp -e "lcd /home/$1; mirror -Rn ${LOCAL_MIRROR}/ ${REMOTE_MIRROR}/; ls ${REMOTE_MIRROR}; bye" -u carrierc,$PASSWORD $SERVER
