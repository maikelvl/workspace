#!/bin/ash
set -e
if [ $DEBUG ]; then
    set -x
fi


start() {
    _set_timezone
    _export_environment_variables
    _create_user
    /usr/sbin/sshd -D
}

build_time() {
    echo -n "Build time: "
    date -d @$(cat /.build-time)
}

version() {
    git --version
}

help() {
    echo "Workspace container commands"
    echo "  start             Starts the SSH daemon"
    echo "  version [args]    Show version info for given program or all"
    echo "  help              Show this help"
}

_set_timezone() {
    if [ -f /usr/share/zoneinfo/$TIMEZONE ];then
        cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    else
        echo "Invalid timezone: $TIMEZONE"
    fi
}

_export_environment_variables() {
    echo '' > /.workspace-env
    env | while read env_var;do
        echo "export $env_var" >> /.workspace-env
    done
}

_create_user() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        if [ ! -d $HOME ];then
            cp -r /tmp/home-template $HOME
        fi
        rm -rf /tmp/home-template
        uid=$(ls /workspace -ld | awk '{print $3}')
        if [ "$uid" == "root" ];then
            adduser $USER -D -h $HOME -s /bin/zsh
        else
            adduser $USER -D -h $HOME -s /bin/zsh -u $uid
        fi
        passwd $USER -d "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
        echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi

    if [ -e /var/run/docker.sock ];then
        chown $USER /var/run/docker.sock
    fi

    if [ ! -d $HOME/.ssh ];then
        mkdir -p -m 700 $HOME/.ssh
        chown $USER $HOME/.ssh
    fi

    cd $HOME
    ssh_dir="$(dirname $SSH_KEY)"
    if [ ! -d "$ssh_dir" ];then
        mkdir -p -m 700 "$ssh_dir"
        chown $USER "$ssh_dir"
    fi

    # Create a key to log in
    if [ ! -f "$SSH_KEY" ];then
        ssh-keygen -f "$SSH_KEY" -N '' -t rsa
        cat "$SSH_KEY.pub" >> $HOME/.ssh/authorized_keys
    fi
}

cmd=${1}
shift
case $cmd in
    start)
        start
        ;;
    build-time)
        build_time
        ;;
    version)
        version
        ;;
    help)
        help
        ;;
    *)
        $cmd $@
        ;;
esac

exit 0