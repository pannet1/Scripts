#!/bin/bash
# X starts after login (startx), so the systemd user manager never sees DISPLAY.
# Import it or D-Bus-activated user services (xdg-desktop-portal-gtk) fail
# with "cannot open display" and retry forever.
systemctl --user import-environment DISPLAY
xsetroot -cursor_name left_ptr &
nm-applet &
# /usr/bin/ibus-daemon -dr &
xfce4-power-manager &
