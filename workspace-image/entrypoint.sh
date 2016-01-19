#!/bin/ash
set -e
if [ $DEBUG ]; then
    set -x
fi

WORKSPACE=${WORKSPACE:$HOME/workspace}
HOME=${HOME:-/Users/$USER}

start() {
    _set_timezone
    _ensure_workspace_git_folder
    _prepare_zsh
    _create_home_directory
    _create_user
    set-docker-client-version
    /usr/sbin/sshd -D
}

build_time() {
    echo -n "Build time: "
    date -d @$(cat /.build-time)
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

_ensure_workspace_git_folder() {
    if [ ! -e $WORKSPACE/.git ] && [ -f $WORKSPACE/upstream-workspace-repo.txt ];then
        branch='master'
        if [ -f $WORKSPACE/upstream-workspace-branch.txt];then
            branch=$(cat $WORKSPACE/upstream-workspace-branch.txt)
        fi
        git clone \
            --no-checkout \
            --branch $branch \
            $(cat $WORKSPACE/upstream-workspace-repo.txt) \
            $WORKSPACE/upstream-workspace \
        && mv $WORKSPACE/upstream-workspace/.git $WORKSPACE/.git \
        && rmdir $WORKSPACE/upstream-workspace
    fi
}

_prepare_zsh() {
    echo "[ -f $WORKSPACE/home/.zshrc ] && source $WORKSPACE/home/.zshrc" > /etc/zsh/zshrc
    echo '' > /etc/zsh/zshenv
    env | while read env_var;do
        echo "export $env_var" >> /etc/zsh/zshenv
    done
    touch $HOME/.zshrc
}

_create_home_directory() {
    if [ ! -d $WORKSPACE/home/ ];then
        cp -r /tmp/home-workspace-template $WORKSPACE/home
    fi

    for file in `find /tmp/home-template/`;do
        home_file="$HOME/${file:19}"
        if [ -f $file ];then
            if [ ! -e $home_file ];then
                cp $file $home_file
            fi
        fi
        if [ -d $file ];then
            if [ ! -d $home_file ];then
                mkdir -p $home_file
            fi
        fi
    done
}

_create_user() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        
        uid=$(ls $WORKSPACE -ld | awk '{print $3}')
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
        exec "$cmd $@"
        ;;
esac

exit 0