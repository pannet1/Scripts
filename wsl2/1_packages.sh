#!/bin/bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y console-setup
echo "console-setup console-setup/codeset47 select UTF-8" | sudo debconf-set-selections
echo "console-setup console-setup/fontface87 select Terminus" | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive console-setup

sudo ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
sudo apt install -y git curl wget fontconfig file tar zip unzip gzip tmux xclip
