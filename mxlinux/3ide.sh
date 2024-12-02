#!/bin/bash
echo "script for configuring zsh, vim and tmux";
echo "run one step at a time till all error vanishes";
dotfiles=$HOME/.dotfiles

if [ "$(logname)" == 'root' ]
  then
    echo "You must not be root to do this."
    exit
fi

if [ ! -d "$dotfiles" ]; then
echo "dotfiles not found cloning from git"
git clone https://github.com/pannet1/dotfiles.git $HOME/.dotfiles        
fi

echo -e "\033[0;31m install oh-my-zsh from git \033[0m "
select yn in "Yes" "No"; do
    case $yn in   
        Yes)         
        cd $HOME;
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended      
       
       mv $HOME/.zshrc /home/$apache_user/.zshrc_mv -v
       ln -s $HOME/.dotfiles/zshrc $HOME/.zshrc -v       
       
       sudo ln -s $HOME/.dotfiles/vimrc /etc/vim/vimrc.local 

      echo "editor /etc/default/keyboard" 
    
     echo "if you want to change the remap caps lock to ctlr key for vim like so
         XKBOPTIONS="ctrl:swapcaps"
        "
    break;;
      No ) break;;
    esac
done


echo -e "\033[0;31m install ZSH autoenv autosuggestions plugin \033[0m "
select yn in "Yes" "No"; do
    case $yn in   
        Yes)         
	git clone git://github.com/inishchith/autoenv.git ~/.autoenv;
               git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.dotfiles/oh-my-zsh/custom}/plugins/zsh-autosuggestions        
               
         break;;
      No ) break;;
    esac
done

echo -e "\033[0;31m install vim plugin \033[0m "
select yn in "Yes" "No"; do
    case $yn in   
        Yes)         
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \\n    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
break;;
      No ) break;;
    esac
done
