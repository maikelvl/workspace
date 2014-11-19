#!/bin/bash

export BLACK="\e[0;30m"
export RED="\e[0;31m"
export GREEN="\e[0;32m"
export ORANGE="\e[0;33m"
export BLUE="\e[0;34m"
export PURPLE="\e[0;35m"
export TURQUASE="\e[0;36m"
export NC="\e[0m"

function info()
{
    printf "$TURQUASE"
    echo -e "$@"
    printf "$NC"
}

function success()
{
    printf "$GREEN"
    echo -e "$@"
    printf "$NC"
}

function warning ()
{
    printf "$orange"
    echo "$1"
    printf "$NC"
}

function error()
{
    printf "$RED"
    echo -e "$@"
    printf "$NC"
}

# ===================================================================================================================

# If this script is for accidently running in run.sh in CoreOS or OSX
if [ ! -d "/workspace" ] || [ -d "/etc/coreos" ]
then
	warning "This script is meant to be running in the Docker workspace (which happens when running the container). Enter 'workspace' to enter it."
	exit
fi

# ===================================================================================================================

SCRIPTS="/scripts"
if [ -d /workspace/scripts ]
then
	SCRIPTS="/workspace/scripts"
fi

for file in $(ls /etc/my_init.d)
do
	/etc/my_init.d/"$file"
done

OH_MY_ZSH_GIT="https://github.com/crobays/oh-my-zsh.git"
OH_MY_ZSH_THEME="crobays"

if [ "$(echo $LOG | awk '{print tolower($0)}')" == "false" ] || [ "$LOG" == "0" ]
then
	LOG=""
else
	LOG=1
fi

if [ $TIMEZONE ] && [ -f "$SCRIPTS/config/php-timezone.sh" ]
then
	$SCRIPTS/config/php-timezone.sh
fi

USERNAME="${USERNAME:-default}"

if [ ! $(getent passwd "$USERNAME") ]
then
	# Set root's password to 'root'
	echo "root:root" | chpasswd

	# Creating the new user account to work with
	useradd "$USERNAME" \
		--create-home \
		--shell $(which zsh) \
		--user-group \
		--groups sudo

	# Copy all roots home content to the new users home
	userhome="$(su "$USERNAME" --command "echo \$HOME")"
	for i in $(ls -A $HOME)
	do
		cp --recursive --no-clobber "$HOME/$i" "$userhome/"
	done
	chown --recursive "$USERNAME:$USERNAME" "$userhome"
	chown --recursive "$USERNAME:$USERNAME" /usr/local/bin
	# Set password same as username
	echo "$USERNAME:$USERNAME" | chpasswd

	if [ "$(which docker)" != "" ]
	then
		# We need group docker to have the same group id as coreos
		groupdel docker && groupadd --gid $(cat /workspace/.system/docker-group-id) docker
		# Make root able to use Docker
		if id --user root >/dev/null 2>&1
		then
			quiet=$(gpasswd --add root docker)
		fi
		# Make user able to use Docker
		if id --user "$USERNAME" >/dev/null 2>&1
		then
			quiet=$(gpasswd --add "$USERNAME" docker)
		fi
	fi

	# Remove the need for entering a password at sudo
	sed -i "s/%sudo	ALL=(ALL:ALL) ALL/%sudo	ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers

	# Install oh-my-zsh
	if [ ! -d "$CONFIG_DIR/oh-my-zsh" ]
	then
		if [ $LOG ]
		then
		    info "Cloning $OH_MY_ZSH_GIT ..."
		fi
		su "$USERNAME" --command "git clone $OH_MY_ZSH_GIT $CONFIG_DIR/oh-my-zsh"
	fi

	# Config oh-my-zsh
	if [ ! -f "$CONFIG_DIR/zshrc" ]
	then
		cp -f "$CONFIG_DIR/oh-my-zsh/templates/zshrc.zsh-template" "$CONFIG_DIR/zshrc"
		sed -i "s/export ZSH=\$HOME\/\.oh-my-zsh/export ZSH=${CONFIG_DIR//\//\\\/}\/oh-my-zsh/" "$CONFIG_DIR/zshrc"
		sed -i "s/plugins=(git)/plugins=(git docker composer rvm)/" "$CONFIG_DIR/zshrc"
		if [ "$OH_MY_ZSH_THEME" != "" ]
		then
			info "Set theme to $OH_MY_ZSH_THEME ..."
			if [ -f "$CONFIG_DIR/oh-my-zsh/themes/$OH_MY_ZSH_THEME.zsh-theme" ]
			then
				sed -i "s/ZSH_THEME=\".*\"/ZSH_THEME=\"$OH_MY_ZSH_THEME\"/" "$CONFIG_DIR/zshrc"
			else
				echo "Unkown theme: $OH_MY_ZSH_THEME in $CONFIG_DIR/oh-my-zsh/themes"
			fi
		fi
		if [ -f "$CONFIG_DIR/shell-profile-workspace" ]
		then
			echo 'source "$CONFIG_DIR/shell-profile-workspace"' >> "$CONFIG_DIR/zshrc"
		fi
	fi

	ln --symbolic --force "$CONFIG_DIR/zshrc" "$userhome/.zshrc"

	# Config
	if [ -f "$SCRIPTS/config/bootstrap.php" ]
	then
		su "$USERNAME" --command "$SCRIPTS/config/bootstrap.php"
	fi

	if [ ! -d "/workspace/.git" ] && [ -f "/workspace/.system/upstream-workspace-repo" ]
	then
		su "$USERNAME" --command "git clone \"$(cat /workspace/.system/upstream-workspace-repo)\" \"/workspace/.workspace-git\""
		mv "/workspace/.workspace-git/.git" "/workspace/.git"
		rm -rf "/workspace/.workspace-git"
		rm -f "/workspace/.system/upstream-workspace-repo"
		su "$USERNAME" --command "cd /workspace && git reset --hard"
	fi

	info "Hi $USERNAME, your password is $USERNAME. (root=root)"
fi

cd "/workspace"
su "$USERNAME"
