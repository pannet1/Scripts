# Define your source and destination base paths
fm="/home/pannet1"
to="/run/media/pannet1/freeagent/latest"

# List of folders you want to mirror
folders=("Personal" "Programs" "Archive" "Documents" "Public" ".config" "Pictures" "Yandex.Disk" "Videos")


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
