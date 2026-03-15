#!/usr/bin/env sh
git add .
if [ -z "$1" ]; then 
    git commit -am "no comments"
else 
    git commit -am "$1"
fi
git push
