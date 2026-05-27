#!/bin/bash

feh --bg-scale --auto-zoom /home/pannet1/Pictures/2.png
picom &
disown # --experimental-backends --vsync should prevent screen tearing on most setups if needed

# Low battery notifier
#~/.config/qtile/scripts/check_battery.sh &
#disown

#/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
#disown # start polkit agent from GNOME

nm-applet &
disown
#blueman-manager & disown

~/.config/qtile/scripts/activity.sh &
disown

redshift -c ~/.config/redshift.conf &
disown

#/usr/bin/ibus-daemon -dr &
# calamares &
# noisetorch &
flameshot &
disown
# easyeffects --gapplication-service &
xfce4-power-manager &
disown
