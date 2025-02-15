#!/bin/bash
echo "script for mxlinux";


if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi

apache_user='pannet1';
data="/media/$apache_user/FAT32/local";
mxlnx='/3linux/mxlinux';
dotfs='/3linux/dotfiles';

apt-get update && apt-get upgrade && apt-get dist-upgrade -y;
cd /home/$apache_user;

echo -e "\033[0;31m Do you wish to automount DATA and HOME directory ? \033[0m "
select yn in "Yes" "No"; do
    case $yn in
        Yes )  blkid;
               echo "edit fstab add below entries and then mount with -ato";
               echo "
               # data
               UUID=75CB798A63D8D26B  /media/pannet1/Data  ntfs-3g defaults,locale=en_US.UTF-8 0 0
                edit and issue mount -a";
               break;;
        No ) break;;
   esac
done

if [ -d "$data" ]; then
    hosting="${data}/2backup/hosting/home";
    echo "hosting dir is .. "$hosting;
    echo -e "\033[0;31m Do you wish to link home directory folders ? \033[0m"
    select yn in "Yes" "No"; do
      case $yn in
        Yes )
        cd;
        rm -rf {Documents,Downloads,Music,Pictures,Public,Templates,Videos};
     	  ln -sTv $data/4documents /home/$apache_user/Documents;
  	    ln -sTv $data/11downloads /home/$apache_user/Downloads;
        ln -sTv $data/6pictures /home/$apache_user/Pictures;
        ln -sTv $data/5public /home/$apache_user/Public;
    	  ln -sTv $data/7music /home/$apache_user/Music;
	      ln -sTv $data/10templates /home/$apache_user/Templates;               
    	  ln -sTv $data/8videos /home/$apache_user/Videos;
      	break;;
        No ) break;;
      esac
    done
else
    echo "data directory $data not found"
    exit
fi

if [ -d "$data" ]; then
    hosting="${data}/2backup/hosting/home";
    echo "hosting dir is .. "$hosting;
    echo -e "\033[0;31m Do you wish to link home folder scripts  ? \033[0m"
    select yn in "Yes" "No"; do
      case $yn in
        Yes )
        echo "linking essential scripts to ~"
        ln -sTv $data/$mxlnx/_dissite.sh /home/$apache_user/_dissite.sh;
        ln -sTv $data/$mxlnx/_ensite.sh /home/$apache_user/_ensite.sh;
        ln -sTv $data/$mxlnx/_createDB.sh /home/$apache_user/_createDB.sh;
        ln -sTv $data/$mxlnx/virtual_host /home/$apache_user/virtual_host;        
      	break;;
        No ) break;;
      esac
    done
else
    echo "data directory $data not found"
    exit
fi

