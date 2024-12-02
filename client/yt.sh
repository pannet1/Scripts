#!/usr/bin/bash
# Download youtube video with desired quality

# youtube-dl accepts both fully qualified URLs and video id's such as AQcQgfvfF1M
# https://askubuntu.com/questions/486297/how-to-select-video-quality-from-youtube-dl
loc="$HOME/Downloads/ytdlp.mp4"
rm "$loc"
url="$*"
echo "Fetching available formats for $url..."
# select the video format for whatsapp
yt-dlp "$url" -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best" -S "codec:h264:aac" --merge-output-format mp4 -o "$loc"
smplayer "$loc"
