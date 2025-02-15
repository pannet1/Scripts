#!/bin/bash
# bash script for removing virtual environment
#


if [ -f "pyvenv.cfg" ]; then
  echo "removing pyvenv.cfg"
  rm pyvenv.cfg
fi 

# unlink lib64 
if [ -d lib64 ]; then
  rm -r lib64
fi
  
# delete list of dirctories
lst = "bin include lib"
for dir in $lst; do
  if [ -d $dir ]; then
    rm -r $dir
  fi
done


