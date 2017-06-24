[ -d "${_TERMSESSION_DATA:-$HOME/.termsessions}" ] && {
    echo "ERROR: termsession-plugin.zsh's datafile (${_TERMSESSION_DATA:-$HOME/.term-session}) is a directory."
}

termsession_path() {
    # ignore when TERM_SESSION_ID is absent
    [ -z "$TERM_SESSION_ID" ] && return
    local datafile="${_TERMSESSION_DATA:-$HOME/.term-sessions}"
    # bail if we don't own ~/.z and $_TERMSESSION_OWNER not set
    [ -z "$_TERMSESSION_OWNER" -a -f "$datafile" -a ! -O "$datafile" ] && return

    if [ "$1" = "--go" ]; then
        unset _TERMSESSION_DISABLE_REGISTER
        local line="$(grep -e "^$TERM_SESSION_ID|.*" $datafile 2>/dev/null)"
        local new_directory="${line:${#TERM_SESSION_ID}+1}"
        if [ "$new_directory" = "$PWD" ] || [ "$new_directory" = "" ] ;then
            return
        fi
        export _TERMSESSION_DISABLE_REGISTER=true
        builtin cd "$new_directory"
        unset _TERMSESSION_DISABLE_REGISTER
    elif [ "$1" = "--register" ]; then
        shift
        if [ ! -z $_TERMSESSION_DISABLE_REGISTER ];then
            return
        fi
        export _TERMSESSION_DISABLE_REGISTER=true
        termsession_path --delete $TERM_SESSION_ID
        echo "$TERM_SESSION_ID|$PWD" >> $datafile
    elif [ "$1" = "--delete" ]; then
        shift
        sed -i -E "/^$1\|.*/d" $datafile
    fi
}

precmd() {
    termsession_path --go
}

chpwd() {
    termsession_path --register
}
