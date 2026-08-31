#!/bin/bash
# X starts after login (startx), so the systemd user manager never sees DISPLAY.
# Import it or D-Bus-activated user services (xdg-desktop-portal-gtk) fail
# with "cannot open display" and retry forever.
systemctl --user import-environment DISPLAY
xsetroot -cursor_name left_ptr &
nm-applet &
# /usr/bin/ibus-daemon -dr &
xfce4-power-manager &

# Fix intermittent audio muting: NVIDIA GA107 HDMI audio probes at boot and
# can cause WirePlumber to re-evaluate sinks, muting the analog output.
# Wait for PipeWire/WirePlumber to settle, then force unmute + restore volume.
(sleep 3 && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0) &
