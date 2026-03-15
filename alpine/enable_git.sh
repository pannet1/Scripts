mkdir -p ~/.ssh
cp /mount/usb/id_ed25519.pub ~/.ssh/id_ed25519.pub
cp /mount/usb/id_ed25519 ~/.ssh/id_ed25519
ls -la ~/.ssh

ssh -V
