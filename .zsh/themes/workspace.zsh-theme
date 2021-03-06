# Fork from gallios.zsh-theme
# Git style from mortalscumbag.zsh-theme
# Collapsed working directory from fishy.zsh-theme

function toggle_git_prompt() {
  if [ $DISABLE_GIT_IN_PROMPT ];then
    DISABLE_GIT_IN_PROMPT=
    echo "Git in prompt"
  else
    DISABLE_GIT_IN_PROMPT=1
    echo "No git in prompt"
  fi
}

function my_git_prompt() {

  tester=$(git rev-parse --git-dir 2> /dev/null) || return

  git_prompt_prefix="$ZSH_THEME_GIT_PROMPT_PREFIX"
  if [ "$HOSTNAME" = "workspace" ] && [ -e $PWD/.disable-git-prompt ];then
    export DISABLE_GIT_IN_PROMPT=true
  fi

  if [ ! $DISABLE_GIT_IN_PROMPT ];then
    INDEX=$(git status --porcelain 2> /dev/null)
    STATUS=""

    # is branch ahead?
    if $(echo "$(git log origin/$(current_branch)..HEAD 2> /dev/null)" | grep '^commit' &> /dev/null); then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_AHEAD"
    fi

    # is anything staged?
    if $(echo "$INDEX" | grep -E -e '^(D[ M]|[MARC][ MD]) ' &> /dev/null); then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STAGED"
    fi

    # is anything unstaged?
    if $(echo "$INDEX" | grep -E -e '^[ MARC][MD] ' &> /dev/null); then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNSTAGED"
    fi

    # is anything untracked?
    if $(echo "$INDEX" | grep '^?? ' &> /dev/null); then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNTRACKED"
    fi

    # is anything unmerged?
    if $(echo "$INDEX" | grep -E -e '^(A[AU]|D[DU]|U[ADU]) ' &> /dev/null); then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNMERGED"
    fi
  else
    git_prompt_prefix="$ZSH_THEME_GIT_PROMPT_PREFIX_DISABLED"
  fi

  if [[ -n $STATUS ]]; then
    STATUS=" $STATUS"
  fi

  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local sha=$(command git rev-parse --short=8 HEAD 2> /dev/null) || return
  if [[ ! $ref ]];then
    ref="$(command git describe --tags --always 2> /dev/null)"
    if [[ "${ref//-g${_sha:0:7}/}" != "${ref}" ]] || [[ "${ref}" == "${sha:0:7}" ]];then
      ref=
    fi
  fi
  echo -n "$git_prompt_prefix%{$fg_no_bold[yellow]%}${sha#refs/heads/}"
  if [[ "$ref" != "" ]]; then
    echo -n "$git_prompt_prefix${ref#refs/heads/}"
  fi

  echo "$STATUS$ZSH_THEME_GIT_PROMPT_SUFFIX"
}

function my_current_branch() {
  echo $(current_branch || echo "(no branch)")
}

function ssh_connection() {
  if [[ -n $SSH_CONNECTION ]]; then
    echo "%{$fg_bold[green]%}%n@%m%{$reset_color%}:"
  fi
}

#Customized git status, oh-my-zsh currently does not allow render dirty status before branch
git_custom_status() {
  local cb=$(current_branch)
  if [ -n "$cb" ]; then
    git_prompt_prefix="$ZSH_THEME_GIT_PROMPT_PREFIX"
    if [ $DISABLE_GIT_IN_PROMT ] || [ -e $PWD/.disable-git-prompt ];then
      git_prompt_prefix="$ZSH_THEME_GIT_PROMPT_PREFIX_DISABLED"
    fi
    echo "$(parse_git_dirty)%{$fg_bold[red]%}$(work_in_progress)%{$reset_color%}$git_prompt_prefix$(current_branch)$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

_fishy_collapsed_wd() {
   echo $(pwd | perl -pe "
    BEGIN {
       binmode STDIN,  ':encoding(UTF-8)';
       binmode STDOUT, ':encoding(UTF-8)';
    }; s|^$HOME|~|g; s|/([^/])[^/]*(?=/)|/\$1|g
 ")
 }

_docker_host() {
  if [ "$DOCKER_MACHINE_NAME" != "" ] && [ "$DOCKER_MACHINE_NAME" != "default" ];then
    echo "%{$fg[green]%}$DOCKER_MACHINE_NAME$reset_color "
  fi
}

_kubectl_prompt() {
  kubeconfig_file="${KUBECONFIG:-$HOME/.kube/config}"
  if [ ! -e "$kubeconfig_file" ];then
    echo "[missing ${kubeconfig_file/$HOME/~}] "
    return
  fi
  kubeconfig="$(j2y -r "$kubeconfig_file" 2>/dev/null)"
  current_context_name="$(echo "$kubeconfig" | jq -r '.["current-context"]')"
  current_cluster_name="$(echo "$kubeconfig" | jq -r ".contexts | map(select(.name == \"$current_context_name\"))[0].context.cluster")"
  current_namespace="$(echo "$kubeconfig" | jq -r ".contexts | map(select(.name == \"$current_context_name\"))[0].context.namespace")"
  if [ "$current_namespace" = "default" ];then
    echo "$current_cluster_name "
  else
    echo "$current_cluster_name/$current_namespace "
  fi
}

# print "$fg_bold[green]$(whoami)$reset_color @ $fg_bold[green]$(uname -n)$reset_color"

path_color=blue
if [ "$HOSTNAME" = "workspace" ];then
  path_color=cyan
fi

PROMPT=$'%{$fg[green]%}$(_kubectl_prompt)%{$fg[$path_color]%}$(_fishy_collapsed_wd)$(my_git_prompt) %(?.%{$fg[yellow]%}.%{$fg[red]%})%B›%b '

ZSH_THEME_PROMPT_RETURNCODE_PREFIX="%{$fg_bold[red]%}"
ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg_bold[yellow]%}"
ZSH_THEME_GIT_PROMPT_PREFIX_DISABLED=" %{$fg_bold[white]%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg_bold[magenta]%}↑"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg_bold[green]%}●"
ZSH_THEME_GIT_PROMPT_UNSTAGED="%{$fg_bold[blue]%}●"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg_bold[red]%}●"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg_bold[red]%}✕"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
