#!/bin/sh
Xephyr -br -ac -noreset -screen 1280x720 :1 & DISPLAY=:1 qtile /home/pannet1/.config/qtile/config.py
