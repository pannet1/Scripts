#!/usr/bin/sh
if [ $# -lt 2 ]
 then 
echo 'usage: <command> localsite serversite'
exit 1;
fi

whoami="$(logname)"
html="/home/$whoami/Programs/php"
echo "enter your mysql password"
mysqldump -u root -p c0$1 > $html/$1/c0$1.sql
rsync -av --update --links --delete --force --stats -e ssh --exclude='.git' --exclude='node_modules' --exclude='*.log' --exclude='tmp' --exclude='*.lock' --exclude='*log' $html/$1/web/ carrierc@ecomsense.in:/home/carrierc/$2
echo "dont forget to move your site $2 from vultr home to webroot"
echo "enter your ssh passwd"
ssh -t carrierc@ecomsense.in "sudo ./scripts/server/_mv_site2web.sh $2; sudo mysqldump -u root -p c0$1 < $html/$2/web/c0$1.sql"
