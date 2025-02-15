#!/bin/sh

if [ $# -eq 0 ]
 then 
 echo 'no argument supplied'
 exit 1;
fi

whoisme="$(logname)";
echo "i am "$whoisme;

bkp="/home/$whoisme/Archive/hosting/home"
web="/home/$whoisme/Programs/php"
dest=$bkp/$1

if [ -d "$dest" ]; then  
   echo "directory exists and will be synced."              
     rsync -avvz --delete --stats --progress '.*' $web/$1/ $bkp/$1
   echo "directory existed and was synced."              
else
    echo "no directory found. copying"
    	cp $web/$1/ $dest -Rv    
    echo "done. copying"
fi
echo "document root and log files removed ."              
    	rm -rv $web/$1 
    
echo "disabling site"
    systemctl stop httpd
    
echo "removing virtual site entry"
    rm -rf /etc/httpd/conf/sites-enabled/$1.conf
    rm -rf /etc/httpd/conf/sites-available/$1.conf
    
echo "removing local host entry"
    sudo sed '/$1/d'  /etc/hosts

echo "removing weekly sunday rysncronjob"
    sed '/$1/d' /home/$whoisme/Scripts/client/rsyncronjobs
    cat /home/$whoisme/Scripts/client/rsyncronjobs

    systemctl start httpd
