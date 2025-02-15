#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "You need to provide the repo name."
  exit 1
fi

if [ -z "$2" ]; then
  echo "You need to provide the github account."
  exit 1
fi

# git clone "https://github.com/$2/starter-code.git" "$1"/

# delete .git folder
# cd "$1"/
# rm -rf .git

git init
git add .
git commit -am "first commit"
git remote add origin "https://github.com/$2/$1.git"
git branch -M main
git push -u origin main
