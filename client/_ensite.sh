#!/bin/bash

if [ $# -eq 0 ]
 then
 echo 'no argument supplied'
 exit 1;
fi

whoisme="$(logname)";
echo "i am "$whoisme;
bkp="/home/$whoisme/Archive/hosting/home"
web="/home/$whoisme//Programs/php";
src="$bkp/$1";

if [ -d "$src" ]; then
    echo "backup found .. at $src";
    sudo mkdir -pv $web/$1/log;
    cp $src  $web/$1 -rv
    echo "copying from backup done";
else
    echo "${src} does not exist. creating .."
    sudo mkdir $web/$1/web -pv
    sudo mkdir $web/$1/log -pv
    
    echo -e "\033[0;31m do you wish to install wordpress database ? \033[0m "
    select yn in "yes" "no"; do
        case $yn in
            yes )  mysqladmin create $1_wp -p
                   break;;
            no ) break;;
        esac
    done
 fi

echo "echo $1" >> /home/$whoisme/Scripts/client/rsyncronjobs
echo "rsync --update --delete --stats --exclude='tmp' --exclude='vendor' --exclude='composer.lock' --exclude='node_modules' /var/www/html/$1 $bkp/" >> /home/$whoisme/Scripts/client/rsyncronjobs
chown "${whoisme}:${whoisme}" $web/$1 -Rv 

cp /home/$whoisme/Scripts/client/virtual_host /etc/httpd/conf/sites-available/$1.conf
sed -i "s/default/$1/g" /etc/httpd/conf/sites-available/$1.conf
sudo chown "${whoisme}:${whoisme}" $web/$1 -Rv 
cd /etc/httpd/conf/sites-enabled/
sudo ln -s ../sites-available/$1.conf $1.conf

cd $web/$1
grep -r "$1" /etc/httpd/conf/sites-available/
sudo echo "127.0.0.1 $1" >> /etc/hosts
sudo systemctl restart httpd
