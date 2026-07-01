#!/bin/sh
apk update
apk add git openssh-client-default
git config --global user.email "prog@ecomsense.in"
git config --global user.name "b karthick"
git config --global url."git@github.com:".insteadOf "https://github.com/"

mkdir -p ~/.ssh
cp /media/usb/id_ed25519.pub ~/.ssh/id_ed25519.pub
cp /media/usb/id_ed25519 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ls -la ~/.ssh

ssh -V
git config --list


# 3. Always save if you install
apk cache sync
lbu commit -d
