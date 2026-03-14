apk update
apk add git ssh-client
git config --global user.email "prog@ecomsense.in"
git config --global user.name "b karthick"
git config --global url."git@github.com:".insteadOf "https://github.com/"

mkdir -p ~/.ssh
ln /mount/usb/id_ed25519.pub ~/.ssh/id_ed25519.pub

echo "add Scripts to path in ~/.bashrc"
