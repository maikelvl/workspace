source $WORKSPACE/.zsh/zshrc-oh-my-zsh
source $WORKSPACE/.zsh/zshrc-extra
ZSH_CUSTOM=$WORKSPACE/home/zsh-custom
source $ZSH_CUSTOM/zshrc-oh-my-zsh
source $ZSH_CUSTOM/zshrc-extra
source $ZSH_CUSTOM/zshrc-local
source $ZSH_CUSTOM/zshrc-keybindings
[ -f $WORKSPACE/home/.zshrc-legacy ] && source $WORKSPACE/home/.zshrc-legacy
