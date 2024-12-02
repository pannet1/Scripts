#!/bin/bash
echo "script for mxlinux";

if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi

apt-get update && apt-get upgrade && apt-get dist-upgrade -y;

echo -e "\033[0;31m install vim, tmux, zsh, git ? \033[0m "
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt-get install sqlitebrowser vim vim-nox ctags tmux xclip zsh taskwarrier fzf fonts-powerline zsh-theme-powerlevel9k zsh-syntax-highlighting git -y;       
       zsh
       chsh -s $(which zsh) 
       echo $SHELL      
       echo "zsh is the new default shell. exit to see the effect"    

      break;;
      No ) break;;
    esac
done


