#!/bin/bash
echo "-- RVM start --"

version="${1:-stable}"

# Creating a temporary user account
tmp_user="tmp-rvm-user"
useradd $tmp_user \
	--create-home \
	--no-user-group \
	--gid sudo

# Make tmp user not have to enter password
sed -i "s/%sudo\tALL=(ALL:ALL) ALL/%sudo\tALL=(ALL) NOPASSWD: ALL/" /etc/sudoers

if [ "$2" != "" ];then
	install_ruby="&& rvm --default use --install $2"
fi

su $tmp_user --command "curl -sSL https://rvm.io/mpapis.asc | gpg --import - && curl --location --silent --url https://get.rvm.io | bash -s $version --ruby --autolibs=enable --auto-dotfiles --quiet-curl && echo 'success' && source /home/$tmp_user/.rvm/scripts/rvm $install_ruby"

# Revert the sudo group settings
sed -i "s/%sudo\tALL=(ALL) NOPASSWD: ALL/%sudo\tALL=(ALL:ALL) ALL/" /etc/sudoers

if [ -d "$HOME/.rvm" ];then
	rm -rf $HOME/.rvm
fi
echo 'export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting' >> "$HOME/.bashrc"
export PATH="$PATH:$HOME/.rvm/bin"
mv /home/$tmp_user/.rvm $HOME/.rvm
echo "Installed: $($HOME/.rvm/bin/rvm --version)"
chown --recursive root:root "$HOME/.rvm"
userdel $tmp_user \
	--remove \
	--force

echo "-- RVM end --"