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
if [ -d /workspace/workspace-image ]
then
	SCRIPTS="/workspace/workspace-image"
fi

if [ ! -d "$CONFIG_DIR" ]
then
	cp -R /root/config-boilerplate "$CONFIG_DIR"
fi

for file in $(ls /etc/my_init.d)
do
	/etc/my_init.d/"$file"
done

if [ "$(echo $LOG | awk '{print tolower($0)}')" == "false" ] || [ "$LOG" == "0" ]
then
	LOG=""
else
	LOG=1
fi

if [ $TIMEZONE ] && [ -f "$SCRIPTS/config-scripts/php-timezone.sh" ]
then
	$SCRIPTS/config-scripts/php-timezone.sh
fi

USERNAME="${USERNAME:-me}"
su "$USERNAME" --command "$SCRIPTS/config-scripts/bootstrap.php"

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

	# Config
	if [ -f "$SCRIPTS/config-scripts/bootstrap.php" ]
	then
		su "$USERNAME" --command "$SCRIPTS/config-scripts/bootstrap.php"
	fi

	info "Hi $USERNAME, your password is $USERNAME. (root=root)"
fi

cd "/workspace"
su "$USERNAME"
