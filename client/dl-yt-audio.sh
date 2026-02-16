#!/usr/bin/bash
# Download youtube video with desired quality

# youtube-dl accepts both fully qualified URLs and video id's such as AQcQgfvfF1M
# https://askubuntu.com/questions/486297/how-to-select-video-quality-from-youtube-dl
loc="$HOME/Downloads/ytdlp.mp3"
rm "$loc"
url="$*"
echo "Fetching available formats for $url..."
# select the audio format for whatsapp
yt-dlp -x --audio-format mp3 "$url" -o "$loc" --concurrent-fragments=16
smplayer "$loc"
