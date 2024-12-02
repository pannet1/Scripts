#!/usr/bin/sh

fm="/home/pannet1";
to="/run/media/pannet1/FAT32/latest";
    echo "copying ... Personal"
    rsync --prune-empty-dirs --progress --recursive --compress --size-only --delete-excluded --stats --exclude='.*/' --exclude='.*' --exclude-from='exclude-rsync.txt' $fm/Personal $to/
    echo "copying ... Archive"
    rsync --prune-empty-dirs --progress --recursive --compress --size-only --delete-excluded --stats --exclude='.*/' --exclude='.*' --exclude-from='exclude-rsync.txt' $fm/Archive $to/
    echo "copying ... Programs"
    rsync --prune-empty-dirs --progress --recursive --compress --size-only --delete-excluded --stats --exclude='.*/' --exclude='.*' --exclude-from='exclude-rsync.txt' $fm/Programs $to/
    echo "copying ... Public"
    rsync --prune-empty-dirs --progress --recursive --compress --size-only --delete-excluded --stats --exclude='.*/' --exclude='.*' --exclude-from='exclude-rsync.txt' $fm/Public $to/
    echo "copying ... .config"
    rsync --prune-empty-dirs --progress --recursive --compress --size-only --delete-excluded --stats --exclude='.git/' --exclude-from='exclude-rsync.txt' $fm/.config/ $to/dotconfig
    #.config/rclone/rclone.conf
    echo "Sync Documents to Grive"
    /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/home/pannet1/Documents" google:Documents
    echo "Sync Pictures to Grive"
    /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/home/pannet1/Pictures" google:Pictures
    echo "Sync Library to yandex"
    /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/home/pannet1/Yandex.Disk" yandex:
    echo "Sync Videos to pcloud"
    # /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/home/pannet1/Videos" pcloud:
    echo "Sync omki to onedrive"
    /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/run/media/pannet1/extra/wedding" msn:
shutdown --poweroff
