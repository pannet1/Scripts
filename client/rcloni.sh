#!/usr/bin/sh

fm="/home/pannet1"
echo "copying ... Personal"
#.config/rclone/rclone.conf
echo "Sync Documents to Grive"
/usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s $fm/Documents google:Documents
echo "Sync Pictures to Grive"
/usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s $fm/Pictues google:Pictures
echo "Sync Library to yandex"
/usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s $fm/Yandex.Disk yandex:
echo "Sync Videos to pcloud"
# /usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/home/pannet1/Videos" pcloud:
echo "Sync omki to onedrive"
/usr/bin/rclone copy --update --verbose --transfers=30 --checkers=8 --contimeout=60s --timeout=300s --retries=5 --low-level-retries=10 --stats 1s "/run/media/pannet1/extra/wedding" msn:
