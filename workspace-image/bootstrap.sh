#!/bin/bash
set -ex

BLACK="\e[0;30m"
RED="\e[0;31m"
GREEN="\e[0;32m"
ORANGE="\e[0;33m"
BLUE="\e[0;34m"
PURPLE="\e[0;35m"
TURQUASE="\e[0;36m"
NC="\e[0m"

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
    printf "$ORANGE"
    echo -e "$@"
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

# if [ ! -f "/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt" ];then
# 	apt-get install -y ca-certificates
# 	mkdir -p /usr/local/opt/curl-ca-bundle/share
# 	cp /etc/ssl/certs/ca-certificates.crt /usr/local/opt/curl-ca-bundle/share/ca-bundle.crt
# fi

# if [ ! -d "$CONFIG_DIR" ]
# then
# 	cp -R /root/config-boilerplate "$CONFIG_DIR"
# fi

# for file in $(ls /etc/my_init.d)
# do
# 	/etc/my_init.d/"$file"
# done

if [ "$(echo $LOG | awk '{print tolower($0)}')" == "false" ] || [ "$LOG" == "0" ]
then
	LOG=""
else
	LOG=1
fi

# if [ $TIMEZONE ] && [ -f "$SCRIPTS/config-scripts/php-timezone.sh" ]
# then
# 	$SCRIPTS/config-scripts/php-timezone.sh
# fi

USERNAME="${USERNAME:-me}"
if [ ! "$(getent passwd $USERNAME)" ]
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

	# Collect enviroment variables and save it for use in SSH session
	if [ -f $userhome/.zsh-env-vars ]
	then
		rm $userhome/.zsh-env-vars
	fi
	while read -r e
	do
		if [[ $e =~ ([A-Z_]+)=.* ]]
		then
			name="${BASH_REMATCH[1]}"
			if [ ${#name} -gt 1 ] && [ "$name" != "HOME" ]
			then
				echo "export ${e/=/=\"}\"" >> $userhome/.zsh-env-vars
			fi
		fi
	done <<< "$(env)"
	chown $USERNAME:$USERNAME $userhome/.zsh-env-vars
	
	# Remove the need for entering a password at sudo
	sed -i "s/%sudo	ALL=(ALL:ALL) ALL/%sudo	ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers

 	# Config
	if [ -f "$SCRIPTS/config-scripts/bootstrap.php" ]
	then
		su "$USERNAME" --command "$SCRIPTS/config-scripts/bootstrap.php"
	fi
	
	ssh-keygen -q -t rsa -f /workspace/.system/workspace_rsa -N ""
	cat /workspace/.system/workspace_rsa.pub >> $userhome/.ssh/authorized_keys
	chmod 600 $userhome/.ssh/authorized_keys
	chown $USERNAME:$USERNAME $userhome/.ssh/authorized_keys

 	info "Hi $USERNAME, your password is $USERNAME. (root=root)"
fi