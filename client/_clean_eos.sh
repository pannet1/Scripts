#!/bin/sh

journalctl --vacuum-time=4weeks
paccache -ruk0
pacman -Rns $(pacman -Qdtq)
reflector --protocol https --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist
eos-rankmirrors --verbose
pacman -Syyu
