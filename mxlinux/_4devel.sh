#!/bin/bash

if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi
apache_user="$(logname)"
echo welcome $apache_user

$server = $(hostname)

echo -e "\033[0;31m Do you wish to install python venv ? \033[0m "
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt-get install python3-tk python3-dev python3-venv -y;
               break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Do you wish to install mariadb? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt-get install mariadb-client mariadb-server -y;
          break;;
        No ) break;;
    esac
done

        
echo -e "done. \033[0;31m Do you wish to secure mariadb ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )   echo "answer yes to all questions and set password "      
		      mysql_secure_installation;
            
             break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Set the password authentication method in MariaDB to native so we can use PHPMyAdmin \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )          
          echo "update mysql.user set plugin = 'mysql_native_password' where user='root';" | mysql -u root                         
        break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m set password for mariadb in debian filE \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )          
          echo "set password in two places for mariadb";
          vi /etc/mysql/debian.cnf;                   
          
         service mysql restart
         netstat -tap | grep mysql
        break;;
        No ) break;;
    esac
done


echo -e "done. \033[0;31m Do you wish to install  apache2 and PHP  ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )             
         
		   apt-get -y install apache2 apache2-doc apache2-utils libapache2-mod-php php7.3 php7.3-common php7.3-gd php7.3-mysql php7.3-imap php7.3-cli php7.3-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt  imagemagick libruby libapache2-mod-python php7.3-curl php7.3-intl php7.3-pspell php7.3-recode php7.3-sqlite3 php7.3-tidy php7.3-xmlrpc php7.3-xsl memcached php-memcache php-imagick php-gettext php7.3-zip php7.3-mbstring memcached libapache2-mod-passenger php7.3-soap php7.3-fpm php7.3-opcache php-apcu libapache2-reload-perl
		   
          a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers actions proxy_fcgi alias
          
          echo "
          <IfModule mod_headers.c>
              RequestHeader unset Proxy early
          </IfModule>" >> /etc/apache2/conf-available/httpoxy.conf

          a2enconf httpoxy;
          echo "ServerName $server" >> /etc/apache2/apache.conf
          service apache2 start

          apt install composer -y
          break;;
        No ) break;;
    esac
done

echo -e "done. \033[0;31m Do you wish to configure Apache2 and PHP7 ? THIS SHOULD BE ONLY ONCE \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )   service apache2 stop
                sed -i "s/www-data/$apache_user/g" /etc/apache2/envvars;
                chown $apache_user:$apache_user /var/www/html -Rv
                service apache2 start

                echo "add following lines to crontab for weekly backup
                59 23 * * 0 /home/$apache_user/Scipts/client/rsyncronjobs >> /home/pannet1/rsync.log 2>&1"


                echo "edit php.ini
                max_execution_time = 120
                max_input_time = 120
                memory_limit = 64M
                upload_max_filesize = 10M
                post_max_size = 10M
                ";

                find / -name 'xdebug.so' 2> /dev/null;
                echo "add following line to php.ini"
               # <<XDEBUG
               # zend_extension="/usr/lib/php5/20060613/xdebug.so";
               # xdebug.remote_enable=On;
               # xdebug.remote_host="localhost;"
               # xdebug.remote_port=9000;
               # xdebug.remote_handler="dbgp";
               # XDEBUG
               break;;
        No ) break;;
    esac
done


echo -e "done. \033[0;31m Do you wish to install nodejs ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
             curl -sL https://deb.nodesource.com/setup_8.x | bash -
             apt-get update -y && apt-get install nodejs -y
             npm install npm --global
             break;;
        No ) break;;
    esac
done


echo -e "done. \033[0;31m Do you wish to clean & remove unwanted packages ? \033[0m"
select yn in "Yes" "No"; do
    case $yn in
        Yes )  echo "done. removing, cleaning and upgrading..."
               apt-get autoremove -y && apt-get autoclean -y
             break;;
        No ) break;;
    esac
done
