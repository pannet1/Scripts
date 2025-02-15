#!/bin/bash
echo "script for mxlinux";

if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi

echo -e "done. \033[0;31m calibre, peek \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            apt-get install calibre -y
	    flatpak install peek
             break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m install all utilities ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )  apt-get install keepass tree tidy unrar p7zip-full exa -y;
            apt-get install mkvtoolnix -y
             break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Do you wish to install chrome eolie palemoon browser? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )   apt-get install icedtea-plugin -y;
		flatpak install Eolie;
                wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb;
                dpkg -i google-chrome-stable_current_amd64.deb;
                rm -rf google-chrome-stable_current_amd64.deb;
                
wget https://download3.operacdn.com/pub/opera/desktop/77.0.4054.90/linux/opera-stable_77.0.4054.90_amd64.deb && 
    dpkg -i opera-stable_77.0.4054.90_amd64.deb;
   rm -rf opera-stable_77.0.4054.90_amd64.deb;
wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
chmod a+rx /usr/local/bin/youtube-dl

             break;;
        No ) break;;
    esac
done


echo -e "\033[0;31m install flapaks telegram freetube ? \033[0m "
select yn in "Yes" "No"; do
    case $yn in
        Yes ) flatpak install telegram.desktop;
              flatpak install FreeTube;
	      flatpak install cherrytree;
	      flatpak install peek;
               break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Do you want to increase tab width for libre calc ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )  
                echo "increase calc tab width by editing the file /usr/share/themes/elementary Dark/gtk-2.0/gtkrc";
                echo "search for GtkScrollbar   ::slider-width"
                break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Do you wish to clean & remove unwanted packages ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )  echo "done. removing, cleaning and upgrading..."
	      apt-get remove kate -y;
              apt-get autoremove -y && apt-get autoclean -y;
              apt-get update && apt-get upgrade && apt-get dist-upgrade -y;
             break;;
        No ) break;;
    esac
done
