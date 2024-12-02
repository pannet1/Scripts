#!/bin/bash
echo "script for mxlinux";

if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi


echo -e "\033[0;31m Do you wish to install FTP TOOLS lftp, rsync, ssh-client ? \033[0m "
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt-get install rsync openssh-client lftp net-tools -y;
              echo "set ssl:verify-certificate no" >> /etc/lftp.conf;
               break;;
        No ) break;;
    esac
done


echo -e "done. \033[0;31m Do you wish install CLOUD SYNC tools grive? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
 
        Yes ) 
	       
wget https://mega.nz/linux/MEGAsync/Debian_10.0/amd64/megasync-Debian_10.0_amd64.deb && dpkg -i megasync-Debian_10.0_amd64.deb
		apt-get install rclone megasync -y;
          echo "add cron entries without sudo;"
       59 23 * * 0 ~/rsyncronjobs >> ~/rsync.log 2>&1
       58 23 * * 0 rclone sync ~/Documents gdrive:/Documents >> ~/rclone.log 2>&1
       57 23 * * 0 yandex-disk sync >> ~/yandex.log 2>&1
          break;;
        No ) break;;
    esac
done


