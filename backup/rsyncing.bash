#!/bin/bash
to="$HOME"
fm="/run/media/$USER/freeagent/latest"

if [ ! -d "$fm" ]; then
  echo "Source path not found: $fm"
  exit 1
fi

folders=("Personal" "Programs" "Archive" "Documents" "Public" "dotfiles" "Pictures" "Yandex.Disk" "Videos")

for folder in "${folders[@]}"; do
  echo "Mirroring $folder..."
  rsync --prune-empty-dirs \
    --progress \
    --recursive \
    --compress \
    --size-only \
    --delete \
    --delete-excluded \
    --stats \
    --exclude-from="exclude_lists/$folder.txt" \
    "$fm/$folder/" "$to/$folder"
  sleep 5
done