#!/bin/ash
set -e
if [ $DEBUG ]; then
    set -x
fi

if ! id -u "$USER" >/dev/null 2>&1; then
    uid=$(ls /workspace -ld | awk '{print $3}')
    adduser $USER -u $uid -D -h $HOME -s /bin/zsh
    passwd $USER -d "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
    echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

if [ ! -d $HOME/.ssh ];then
    mkdir -m 700 $HOME/.ssh
    chown $USER $HOME/.ssh
fi

if [ -e /var/run/docker.sock ];then
    chown $USER /var/run/docker.sock
fi

if [ ! -f $HOME/.ssh/workspace_rsa ];then
    ssh-keygen -f $HOME/.ssh/workspace_rsa -N '' -t rsa
    cat $HOME/.ssh/workspace_rsa.pub >> $HOME/.ssh/authorized_keys
fi
