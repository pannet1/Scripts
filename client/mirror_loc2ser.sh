#!/bin/bash
SERVER="carrierconnections.net"
USERNAME="carrierc"
PASSWORD="carr1erc13"

if [ $# -eq 1 ]
 then 
 echo 'usage command <localpath/dir> /home/carrierc/<folder>'
 exit 1;
fi
lftp -e "mirror -Rn $1/ $2/; bye" -u $USERNAME,$PASSWORD $SERVER
