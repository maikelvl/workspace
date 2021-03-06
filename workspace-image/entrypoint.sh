#!/bin/ash
set -e
[ $DEBUG ] && set -x

set -o allexport
source $WORKSPACE_SETTINGS_FILE
set +o allexport

HOME=${HOME:-/Users/$USER}
[ ! -d "$WORKSPACE" ] && echo 'Please set a valid WORKSPACE env' && exit 1
[ "$WORKSPACE_SSH_KEY" == "" ] && echo 'Please set env WORKSPACE_SSH_KEY' && exit 1

start() {
    _set_timezone
    _ensure_workspace_git_folder
    _create_home_directory
    _prepare_zsh
    _create_user
    set-docker-client-version
    /usr/sbin/sshd -p $SSH_PORT -D
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
    if [ ! -d  $WORKSPACE/.oh-my-zsh ];then
        cp -r /var/lib/oh-my-zsh $WORKSPACE/.oh-my-zsh
    fi

    echo "[ -f $WORKSPACE/home/.zshrc ] && source $WORKSPACE/home/.zshrc" > /etc/zsh/zshrc

    echo '' > /etc/zsh/zshenv
    env | while read env_var;do
        if [ "${env_var:0:4}" == "PWD=" ];then
            continue
        fi
        echo "export $env_var" >> /etc/zsh/zshenv
    done
    echo "export KREW_ROOT=\"${WORKSPACE}/home/.krew\"" >> /etc/zsh/zshenv
    echo 'export PATH="${KREW_ROOT}/bin:${PATH}"' >> /etc/zsh/zshenv
    echo '[ -e $WORKSPACE/.zsh/zshenv ] && source $WORKSPACE/.zsh/zshenv' >> /etc/zsh/zshenv
}

_create_home_directory() {
    if [ ! -d $WORKSPACE/home/ ];then
        cp -r /tmp/home-workspace-template $WORKSPACE/home
        chown -R $USER $WORKSPACE/home
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

    if [ -f $HOME/.zshrc ] && [ ! -L $HOME/.zshrc ];then
        cat $HOME/.zshrc >> $WORKSPACE/home/zsh-custom/zshrc-legacy
        echo '[ -e $WORKSPACE/home/zsh-custom/zshrc-legacy ] && source $WORKSPACE/home/zsh-custom/zshrc-legacy' >> $WORKSPACE/home/zsh-custom/zshrc-local
    fi
    ln -sf $WORKSPACE/.zsh/zshrc $HOME/.zshrc

    mkdir -p $HOME/.autoenv
    ln -sfn ${WORKSPACE/$HOME\//}/workspace-image/autoenv-activate.sh $HOME/.autoenv/activate.sh
}

_create_user() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        uid=$(ls $WORKSPACE -ld | awk '{print $3}')
        if [ "$uid" == "root" ];then
            adduser $USER -D -h $HOME -s /bin/zsh
        else
            adduser $USER -D -h $HOME -s /bin/zsh -u $uid
        fi
        echo "$USER:$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" | chpasswd
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
    ssh_dir="$(dirname $WORKSPACE_SSH_KEY)"
    if [ ! -d "$ssh_dir" ];then
        mkdir -p -m 700 "$ssh_dir"
        chown $USER "$ssh_dir"
    fi

    # Create a key to log in if not existing
    [ ! -f "$WORKSPACE_SSH_KEY" ] && su -c "ssh-keygen -f '$WORKSPACE_SSH_KEY' -N '' -t rsa -C '$USER@workspace-host $(date)'" $USER

    # Add the ssh key to the authorized keys if not present
    grep -Fxq "$(cat $WORKSPACE_SSH_KEY.pub)" $HOME/.ssh/authorized_keys || cat $WORKSPACE_SSH_KEY.pub >> $HOME/.ssh/authorized_keys
}

$@
