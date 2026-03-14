apk update
apk add git openssh-client-common
git config --global user.email "prog@ecomsense.in"
git config --global user.name "b karthick"
git config --global url."git@github.com:".insteadOf "https://github.com/"
git config --global list

mkdir -p ~/.ssh
ln /mount/usb/id_ed25519.pub ~/.ssh/id_ed25519.pub
ls ~/.ssh

echo "add Scripts to path in ~/.profile"
cat ~/.profile
