#!/bin/bash
picom &
xsetroot -cursor_name left_ptr &
nm-applet &
/usr/bin/ibus-daemon -dr &
xfce4-power-manager &
