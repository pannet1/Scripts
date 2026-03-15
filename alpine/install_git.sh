apk update
apk add git openssh-client-default
git config --global user.email "prog@ecomsense.in"
git config --global user.name "b karthick"
git config --global url."git@github.com:".insteadOf "https://github.com/"
git config --global list

mkdir -p ~/.ssh
cp /mount/usb/id_ed25519.pub ~/.ssh/id_ed25519.pub
cp /mount/usb/id_ed25519 ~/.ssh/id_ed25519
ls -la ~/.ssh

ssh -V
echo "add Scripts to path in ~/.profile"
cat ~/.profile
