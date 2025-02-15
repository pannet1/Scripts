#!/usr/bin/sh

if [ $# -eq 0 ]
 then 
 echo 'no argument supplied'
 exit 1;
fi

proj_dir="$(pwd)/$1";

if [ -d "$proj_dir" ]; then  
   echo "project found .. at $proj_dir";
else 
	mkdir -pv $proj_dir;
fi

cd $proj_dir;
env_dir="$(pwd)/env";
if [ -d "$env_dir" ]; then
  echo "found env";
  ln -s $env_dir env -vr;
  source env/bin/activate;
else
  echo "env dir not found"
  echo "create it manually"
  echo 'python3 -m venv env';
fi
