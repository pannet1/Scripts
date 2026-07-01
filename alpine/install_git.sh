#!/bin/sh
apk update
apk add git openssh-client-default
git config --global user.email "prog@ecomsense.in"
git config --global user.name "b karthick"
git config --global credential.helper store
git config --list
echo "add Scripts to path in ~/.profile"
cat ~/.profile


# 3. Always save if you install
apk cache sync
touch /media/usb/.boot_repository
lbu commit -d
