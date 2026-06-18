#!/bin/bash
#
# Description:  automatic system update
#
# Usage:        system_update
#
# Example:      ./system_update
#
# Author:       VDA
#
# Last update: 2019.07.03
#

[ $EUID -ne 0 ] && { echo "$0 - Error: you must be root to run this script."; exit 1; }

pacman -Syy
[ $(pacman -Su --print | wc -c) == 0 ] && { echo "No updates avaible"; exit 1; }

pacman -Syy && pacman -Su --noconfirm && reboot

exit 0
