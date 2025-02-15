 #!/bin/bash
whoami="pannet1"

if [ $# -eq 0 ]
 then 
 echo 'usage: getwp localsite'
 exit 1;
fi
wget https://wordpress.org/latest.zip
unzip latest.zip
dest="/var/www/html/$1/web";
echo $dest;
if [ -d "$dest" ]; then  
   echo "copying wordpress to $dest";              
   cp wordpress/. $dest -Rv;
   echo "changing permissions recursively";
   chown pannet1:pannet1 $dest -Rv;
   echo "cleaning up download wordpress archive"
   rm -rf latest.zip wordpress;
   cd $dest;
   cd ..;
   find . -type d -print -exec chmod 755 {} \;   
   find . -type f -print -exec chmod 644 {} \;
   cd $dest;	
   ls -la;
else
   echo "$dest not found. check if folder exists and try again" 
fi
