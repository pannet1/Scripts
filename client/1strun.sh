qtile
atool xclip highlight
ranger pcmanfm-gtk3
picom lightdm lightdm-gtk-greeter lxappearance
oasystray i3lock
alsa-utils amixer alsamixer
rofi nitrogen
nerd-fonts-jetbrains-mono nerd-fonts-mononoki nerd-fonts-source-code-pro ttf-dejavu ttf-liberation noto-fonts ttf-cascadia-code
xorg-server-xephyr
rofi-theme-selector arc-gtk-theme-eos papirus-icon-theme
neovim
libreoffice-still
virtualbox virtualbox-guest-iso
feh
Xephyr -br -ac -noreset -screen 1280x720 :1 &
[200~DISPLAY=:1 qtile "/home/pannet1/.config/qtile/config.py"
echo "add ~/.xprofile with setxkbmap, picom and nitrogen"
rofi -dump-config >~/.config/rofi/config.rasi
blueman
sudo systemctl enable bluetooth
sudo pacman -S --needed - <packages-repository.txt
sudo systemctl start lightdm
