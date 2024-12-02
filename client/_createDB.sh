#!/bin/bash
  
EXPECTED_ARGS=1
E_BADARGS=65
MYSQL=`which mysql`
  
Q1="CREATE DATABASE IF NOT EXISTS $1;"
Q2="GRANT USAGE ON *.* TO carrierc_root@localhost IDENTIFIED BY 'carrierc_carr1erc13';"
Q3="GRANT ALL PRIVILEGES ON $1.* TO carrierc_root@localhost;"
Q4="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}${Q4}"
  
if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: $0 dbname"
  exit $E_BADARGS
fi
  
$MYSQL -u root -p -e "$SQL"
echo $Q1;
echo $Q2;
echo $Q3;
echo $Q4;
