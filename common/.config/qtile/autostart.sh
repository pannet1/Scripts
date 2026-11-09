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

# ALC3220 analog path. alsa-restore.service replays /var/lib/alsa/asound.state
# at boot, which sets Capture to +12dB with nothing plugged in, and the card
# can present with the speaker amp shut. Single source of truth is the script;
# the systemd user service (alc3220-audio-fix.service) runs the same thing
# earlier, this is a re-assert after X/PipeWire have settled.
(sleep 3 && ~/.local/bin/alc3220-audio-fix) &

# Compositor. Used to be a systemd user unit (picom.service), but it was
# WantedBy=default.target, which fires at boot before startx has brought X up,
# and After=graphical-session.target never reached a real target (startx on a
# TTY does not create one). That left it failing "Can't open display" a few
# times every boot and letting systemd's restart backoff paper over it.
# Started here instead, after X is guaranteed to be up.
picom &
