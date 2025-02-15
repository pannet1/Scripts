#!/bin/bash
sudo mount /dev/sda5 /mnt  # make sure that sda2 is correct!
for i in /sys /proc /run /dev; do sudo mount --bind "$i" "/mnt$i"; done
sudo chroot /mnt
update-grub
