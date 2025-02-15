#!/bin/bash
mv $1 split.mkv
mkvmerge --split duration:00:50:00.000 split.mkv -o $1
rm -rf split.mkv
