#!/bin/bash
set -e
[ $DEBUG ] && set -x
#YES_TO_ALL=1

WORKSPACE_BRANCH="develop"
WORKSPACE_REPO="https://github.com/crobays/workspace/archive/$WORKSPACE_BRANCH.zip"
VAGRANT_DOWNLOADS_LINK="http://www.vagrantup.com/downloads"
VIRTUALBOX_DOWNLOADS_LINK="https://www.virtualbox.org/wiki/Downloads"
VMWARE_FUSION_DMGS="
https://download3.vmware.com/software/fusion/file/VMware-Fusion-6.0.6-2684343.dmg
https://download3.vmware.com/software/fusion/file/VMware-Fusion-7.1.3-3204469.dmg
https://download3.vmware.com/software/fusion/file/VMware-Fusion-8.0.2-3164312.dmg
"

GLOBAL_TEMP_DIR=`mktemp -d -t workspace`
DOWNLOAD_DIR="$HOME/Downloads"
WORKSPACE_ZIP="$DOWNLOAD_DIR/workspace.zip"
UPDATE_UNINSTALLER=1
DEFAULT_WORKSPACE="~/workspace"
DEFAUlT_HOSTNAME="$(hostname -s)"
DEFAULT_USERNAME=`whoami`
DEFAULT_VAGRANT_VERSION="1.7.4"
DEFAUlT_COREOS_RELEASE_CHANNEL="stable"
DEFAULT_PROVIDER="virtualbox"
DEFAULT_VMWARE_FUSION_VERSION="6"

VAGRANT_LINK= #"https://releases.hashicorp.com/vagrant/1.7.4/vagrant_1.7.4.dmg"
VIRTUALBOX_LINK= #"http://download.virtualbox.org/virtualbox/5.0.10/VirtualBox-5.0.10-104061-OSX.dmg"
VIRTUALBOX_EXT_PACK_LINK= #"http://download.virtualbox.org/virtualbox/5.0.10/Oracle_VM_VirtualBox_Extension_Pack-5.0.10-104061.vbox-extpack"
VMWARE_FUSION_LINK=

INSTALL_VAGRANT=
INSTALL_PROVIDER=

VAGRANT_INSTALLER=
VIRTUALBOX_INSTALLER=
VIRTUALBOX_EXT_PACK_INSTALLER=
VMWARE_FUSION_INSTALLER=


_workspace_install_start() {
	_workspace_install_read_workspace
	_workspace_install_read_docker_machine
	_workspace_install_read_vagrant
	_workspace_install_read_provider
	_workspace_install_read_environment_file

	mkdir -p "$DOWNLOAD_DIR"
	
	_workspace_install_download_workspace

	if [ $INSTALL_DOCKER_MACHINE ];then
		_workspace_install_download_docker_machine
	fi

	if [ $INSTALL_VAGRANT ];then
		_workspace_install_download_vagrant
	fi

	if [ $INSTALL_PROVIDER ];then
		_workspace_install_download_provider
	fi
	
	_workspace_install_install_workspace
	
	if [ $INSTALL_DOCKER_MACHINE ];then
		_workspace_install_install_docker_machine
	fi

	if [ $INSTALL_VAGRANT ];then
		_workspace_install_install_vagrant
		echo "" && vagrant plugin install vagrant-triggers
		if [ "$PROVIDER" == "vmware-fusion" ];then
			echo "" && vagrant plugin install vagrant-vmware-fusion
			echo "" && vagrant plugin license vagrant-vmware-fusion $GLOBAL_TEMP_DIR/license-vagrant-vmware-fusion.lic
		fi
	fi

	if [ $INSTALL_PROVIDER ];then
		_workspace_install_install_provider
	fi
	_workspace_install_install_environment_file
	
	_workspace_install_add_to_bash_profile "alias coreos=\"\$WORKSPACE/coreos\""
	_workspace_install_add_to_bash_profile "alias workspace=\"\$WORKSPACE/workspace\""
	_workspace_install_add_to_bash_profile "alias ws=\"workspace ssh --force\""

	_workspace_install_trash "$GLOBAL_TEMP_DIR"

	echo ""
	_workspace_install_success "Awesome! You are successfully setup!"
	_workspace_install_info "Open a new terminal window to activate the new commands. (or run 'source ~/.bash_profile')"
	_workspace_install_info "Then you can run 'workspace ssh' to bring the workspace up and ssh into it."
	_workspace_install_success "Happy coding! 😉"
}

_workspace_install_read_workspace() {
	echo ""
	[ $YES_TO_ALL ] || read -e -p "Workspace location [$DEFAULT_WORKSPACE]: " WORKSPACE
	WORKSPACE="${WORKSPACE:-$DEFAULT_WORKSPACE}"
	WORKSPACE="${WORKSPACE/\~/$HOME}"
	if [ -e "$WORKSPACE" ];then
		if [ -f "$WORKSPACE/.system/uninstall.sh" ];then
			echo ""
			_workspace_install_warning "Another workspace is installed in this location."
			if _workspace_install_confirm "Do you want to uninstall the current workspace?";then
				_workspace_install_info "Uninstalling..."
				bash "YES_TO_ALL=$YES_TO_ALL && source $WORKSPACE/.system/uninstall.sh"
			else
				exit
			fi
		fi
		if [ -e "$WORKSPACE" ];then
			_workspace_install_warning "This location already exists."
			if [ $YES_TO_ALL ];then
				_workspace_install_trash "$WORKSPACE"
			else
				_workspace_install_read_workspace
				return
			fi
		fi
	fi
	if [ "${WORKSPACE:0:1}" != "/" ];then
		WORKSPACE="$HOME/$WORKSPACE"
	fi
	export WORKSPACE="${WORKSPACE/\~/$HOME}"
}

_workspace_install_read_docker_machine() {
	if [ "$(which docker-machine)" != "" ];then
		docker_machine_installed=1
		docker_machine_version="`docker_machine --version | sed -En 's/[^0-9]*([0-9]*\.[0-9]*\.[0-9]*).*/\1/p'`"
		_workspace_install_success "Docker Machine $docker_machine_version is installed"
	fi
	echo ""
	if [ ! $docker_machine_installed ];then
		_workspace_install_warning "Docker machine is not installed."
		prompt="Should I install Docker Machine for you?"
	else
		prompt="Should I install a specific/newer Docker Machine for you?"
	fi

	INSTALL_DOCKER_MACHINE=
	if ! _workspace_install_confirm "$prompt";then
		echo "" && read -p "Please press 'Enter/Return' when you have installed Docker Machine. " proceed
		_workspace_install_read_docker_machine
	else
		echo ""
		DEFAULT_DOCKER_MACHINE_VERSION="$(curl --url https://github.com/docker/machine/releases/latest | sed -rn 's/.*tag\/v([^\"]*).*/\1/p')"
		[ $YES_TO_ALL ] || read -p "Which Docker Machine version? [$DEFAULT_DOCKER_MACHINE_VERSION]: " DOCKER_MACHINE_VERSION
		DOCKER_MACHINE_VERSION="${DOCKER_MACHINE_VERSION:-$DEFAULT_DOCKER_MACHINE_VERSION}"
		INSTALL_DOCKER_MACHINE=1
	fi
}

_workspace_install_read_vagrant() {
	if [ "$(which vagrant)" != "" ];then
		vagrant_installed=1
		vagrant_version="`vagrant --version | sed -En 's/[^0-9]*([0-9]*\.[0-9]*\.[0-9]*).*/\1/p'`"
		_workspace_install_success "Vagrant $vagrant_version is installed"
	fi
	if [ "$DEFAULT_VAGRANT_VERSION" == "$vagrant_version" ];then
		return
	fi
	echo ""
	if [ ! $vagrant_installed ];then
		_workspace_install_warning "Vagrant is not installed."
		prompt="Should I install Vagrant for you?"
	else
		prompt="Should I install a specific/newer Vagrant for you?"
	fi
	DEFAULT_VAGRANT_HOME="$WORKSPACE/.vagrant.d"
	if [ $VAGRANT_HOME ];then
		DEFAULT_VAGRANT_HOME="$VAGRANT_HOME"
	elif [ -d "$HOME/.vagrant.d" ];then
		DEFAULT_VAGRANT_HOME="$HOME/.vagrant.d"
	fi
	VAGRANT_HOME="${VAGRANT_HOME:-$DEFAULT_VAGRANT_HOME}"
	export VAGRANT_HOME="${VAGRANT_HOME/\~/$HOME}"

	INSTALL_VAGRANT=
	if ! _workspace_install_confirm "$prompt";then
		mkdir -p "$VAGRANT_HOME"
		_workspace_install_add_to_bash_profile "export VAGRANT_HOME=\"${VAGRANT_HOME/$WORKSPACE/\$WORKSPACE}\""
		echo "" && read -p "Please press 'Enter/Return' when you have installed Vagrant. " proceed
		_workspace_install_read_vagrant
	else
		echo ""
		[ $YES_TO_ALL ] || read -p "Which Vagrant version? [$DEFAULT_VAGRANT_VERSION]: " VAGRANT_VERSION
		VAGRANT_VERSION="${VAGRANT_VERSION:-$DEFAULT_VAGRANT_VERSION}"
		
		echo ""
		[ $YES_TO_ALL ] || read -p "Vagrant home [${DEFAULT_VAGRANT_HOME/$HOME/~}]: " VAGRANT_HOME
		VAGRANT_HOME="${VAGRANT_HOME:-$DEFAULT_VAGRANT_HOME}"
		export VAGRANT_HOME="${VAGRANT_HOME/\~/$HOME}"
		INSTALL_VAGRANT=1
	fi
}

_workspace_install_read_provider() {
	echo ""
	echo "You need a virtual machine provider. Which one do you want to use?"
	echo -n "1. VirtualBox"; _workspace_install_provider_is_installed virtualbox && echo -n " (installed)"; echo ""
	echo -n "2. VMware Fusion"; _workspace_install_provider_is_installed vmware-fusion && echo -n " (installed)"; echo ""
	PROVIDER=
	while [ ! $PROVIDER ];do
		[ $YES_TO_ALL ] || read -p "Please make a choice: [$DEFAULT_PROVIDER] " PROVIDER
		PROVIDER=${PROVIDER:-$DEFAULT_PROVIDER}
		PROVIDER=`echo "$PROVIDER" | awk '{print tolower($0)}'`
		case $PROVIDER in
			1|"virtualbox")
				PROVIDER=virtualbox
				if _workspace_install_provider_is_installed $PROVIDER;then
					_workspace_install_success "$PROVIDER already installed."
					return
				fi
				;;
			2|vmware-fusion|"vmware fusion")
				PROVIDER=vmware-fusion
				echo ""
				echo "The VMware Fusion provider requires two software licenses:"
				echo " - VMware Fusion license                   (http://vmware.com/support/fusion/faq/licensing)"
				echo " - Vagrant VMware Fusion plugin license    (http://www.vagrantup.com/vmware)"
				if ! _workspace_install_confirm "Are you aware of this?";then
					_workspace_install_read_provider
					return
				fi
				if [ ! -f "$VAGRANT_HOME/license-vagrant-vmware-fusion.lic" ];then
					_workspace_install_read_vmware_fusion_vagrant_license
				fi
				;;
			*)
				PROVIDER=
				;;
		esac
	done

	if _workspace_install_provider_is_installed $PROVIDER;then
		echo ""
		_workspace_install_success "`_workspace_install_provider_nice_name $PROVIDER` is already installed."
		return
	fi

	echo ""
	_workspace_install_warning "`_workspace_install_provider_nice_name $PROVIDER` is not installed."
	if _workspace_install_confirm "Should I install `_workspace_install_provider_nice_name $PROVIDER` for you?";then
		case $PROVIDER in
			virtualbox)
				;;
			vmware-fusion)
				_workspace_install_read_vmware_fusion
				;;
		esac
		INSTALL_PROVIDER=1
	else
		echo ""
		read -p "Please press 'Enter/Return' when you have installed `_workspace_install_provider_nice_name $PROVIDER`. " proceed
		if _workspace_install_provider_is_installed $PROVIDER;then
			_workspace_install_success "`_workspace_install_provider_nice_name $PROVIDER` installed."
		else
			_workspace_install_read_provider
		fi
	fi
}

_workspace_install_read_vmware_fusion() {
	echo ""
	echo "There are several versions of VMware Fusion:"
	echo "$VMWARE_FUSION_DMGS" | while read link;do
		if [ ! $link ];then
			continue
		fi
		version=`echo $link | sed -En 's/.*-([0-9]*\.[0-9]*\.[0-9]*).*/\1/p'`
		echo "${version:0:1}. $version"
	done
	VMWARE_FUSION_LINK=
	while [ ! $VMWARE_FUSION_LINK ];do
		[ $YES_TO_ALL ] || read -p "Which VMware Fusion version do you want to install? [$DEFAULT_VMWARE_FUSION_VERSION] " VMWARE_FUSION_VERSION
		VMWARE_FUSION_VERSION=${VMWARE_FUSION_VERSION:-$DEFAULT_VMWARE_FUSION_VERSION}
		VMWARE_FUSION_LINK=`_workspace_install_get_vmware_fusion_link $VMWARE_FUSION_VERSION`
	done
}

_workspace_install_read_vmware_fusion_vagrant_license() {
	echo ""
	echo "Please tell where your Vagrant VMware Fusion license is located."
	echo "You may place it in '$HOME' or provide the path (local or over the network)."
	while [ ! $VAGRANT_VMWARE_FUSION_LICENSE ];do
		if [ "$(ls $HOME/*.lic 2>/dev/null)" == "" ];then
			[ $YES_TO_ALL ] || read -p "(e.g. ~/directory/license.lic or user@10.0.1.2:license.lic): " VAGRANT_VMWARE_FUSION_LICENSE
		fi
		if [ ! $VAGRANT_VMWARE_FUSION_LICENSE ];then
			if [ "$(ls $HOME/*.lic 2>/dev/null)" != "" ];then
				VAGRANT_VMWARE_FUSION_LICENSE="$(ls $HOME/*.lic)"
			else
				if [ $YES_TO_ALL ];then
					_workspace_install_error "Please, place your Vagrant VMware Fusion license in '$HOME'."
					exit
				fi
				_workspace_install_warning "~/*.lic: No license file found."
				continue
			fi
		fi
		VAGRANT_VMWARE_FUSION_LICENSE=${VAGRANT_VMWARE_FUSION_LICENSE/\~/$HOME}
		if [ "${VAGRANT_VMWARE_FUSION_LICENSE:0:1}" != "/" ] && [ "${VAGRANT_VMWARE_FUSION_LICENSE/:/}" == "$VAGRANT_VMWARE_FUSION_LICENSE" ];then
			VAGRANT_VMWARE_FUSION_LICENSE="$HOME/$VAGRANT_VMWARE_FUSION_LICENSE"
		fi
		if ! scp "$VAGRANT_VMWARE_FUSION_LICENSE" "$GLOBAL_TEMP_DIR/" 2>/dev/null;then
			_workspace_install_error "${VAGRANT_VMWARE_FUSION_LICENSE/$HOME/~}: No such file or directory."
			VAGRANT_VMWARE_FUSION_LICENSE=
			continue
		fi
		
		if [ ! -f "$GLOBAL_TEMP_DIR/"*.lic ];then
			_workspace_install_error "${VAGRANT_VMWARE_FUSION_LICENSE/$HOME/~}: No license file found."
			VAGRANT_VMWARE_FUSION_LICENSE=
			continue
		fi
		mv $GLOBAL_TEMP_DIR/*.lic $GLOBAL_TEMP_DIR/license-vagrant-vmware-fusion.lic
	done
	_workspace_install_success "License file found!"
}

_workspace_install_download_workspace() {
	download_link="$WORKSPACE_REPO"
	if [ -f $WORKSPACE_ZIP ];then
		return
	fi
	_workspace_install_info "Downloading Workspace"
	_workspace_install_info "($download_link)..."
	curl --location --url "$download_link" --output "$WORKSPACE_ZIP" 
}

_workspace_install_get_vmware_fusion_link() {
	echo "$VMWARE_FUSION_DMGS" | while read link;do
		version=`echo $link | sed -En 's/.*-([0-9]*\.[0-9]*\.[0-9]*).*/\1/p'`
		if [ "${version:0:1}" != "$VMWARE_FUSION_VERSION" ] && [ "$version" != "$VMWARE_FUSION_VERSION" ];then
			continue
		fi
		echo "$link"
		break
	done
}

_workspace_install_download_docker_machine() {
	download_link="https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine_darwin-amd64"

	DOCKER_MACHINE_BINARY="$DOWNLOAD_DIR/docker-machine-v$DOCKER_MACHINE_VERSION"
	if [ -f $DOCKER_MACHINE_BINARY ];then
		return
	fi
	_workspace_install_info "Downloading Docker Machine v$DOCKER_MACHINE_VERSION"
	_workspace_install_info "($download_link)..."
	
	sudo curl \
 		--location \
		--url $download_link \
		--output $DOCKER_MACHINE_BINARY \
}

_workspace_install_download_vagrant() {
	pattern="vagrant*.dmg"
	_workspace_install_info "Searching $VAGRANT_DOWNLOADS_LINK for $pattern ($VAGRANT_VERSION)..."
	download_link="${VAGRANT_LINK:-$(_workspace_install_find_download_link "$VAGRANT_DOWNLOADS_LINK" "$pattern" "$VAGRANT_VERSION")}"
	if [ "$download_link" == "" ];then
		_workspace_install_error "No $pattern found on $VAGRANT_DOWNLOADS_LINK."
		return
	fi
	VAGRANT_INSTALLER="$DOWNLOAD_DIR/$(basename $download_link)"
	if [ -f $VAGRANT_INSTALLER ];then
		return
	fi
	_workspace_install_info "Downloading Vagrant $VAGRANT_VERSION"
	_workspace_install_info "($download_link)..."
	curl --location --url "$download_link" --output "$VAGRANT_INSTALLER" 
}

_workspace_install_download_provider() {
	case $PROVIDER in
		virtualbox)
			_workspace_install_download_virtualbox
			_workspace_install_download_virtualbox_extension_pack
			;;
		vmware-fusion)
			_workspace_install_download_vmware_fusion
			;;
	esac
}

_workspace_install_download_virtualbox() {
	pattern="VirtualBox*-OSX.dmg"
	_workspace_install_info "Searching $VIRTUALBOX_DOWNLOADS_LINK for $pattern..."
	download_link="${VIRTUALBOX_LINK:-$(_workspace_install_find_download_link "$VIRTUALBOX_DOWNLOADS_LINK" "$pattern")}"
	if [ "$download_link" == "" ];then
		_workspace_install_error "No $pattern found on $VIRTUALBOX_DOWNLOADS_LINK."
		return
	fi
	VIRTUALBOX_INSTALLER="$DOWNLOAD_DIR/$(basename $download_link)"
	if [ -f $VIRTUALBOX_INSTALLER ];then
		return
	fi
	_workspace_install_info "Downloading Virtualbox"
	_workspace_install_info "($download_link)..."
	curl --location --url "$download_link" --output "$VIRTUALBOX_INSTALLER" 
}

_workspace_install_download_virtualbox_extension_pack() {
	pattern="Oracle_VM_VirtualBox_Extension_Pack-*.vbox-extpack"
	_workspace_install_info "Searching $VIRTUALBOX_DOWNLOADS_LINK for $pattern..."
	download_link="${VIRTUALBOX_EXT_PACK_LINK:-$(_workspace_install_find_download_link "$VIRTUALBOX_DOWNLOADS_LINK" "$pattern")}"
	if [ "$download_link" == "" ];then
		_workspace_install_error "No $pattern found on $VIRTUALBOX_DOWNLOADS_LINK."
		return
	fi
	VIRTUALBOX_EXT_PACK_INSTALLER="$DOWNLOAD_DIR/$(basename $download_link)"
	if [ -f $VIRTUALBOX_EXT_PACK_INSTALLER ];then
		return
	fi
	_workspace_install_info "Downloading Virtualbox Extension Pack"
	_workspace_install_info "($download_link)..."
	curl --location --url "$download_link" --output "$VIRTUALBOX_EXT_PACK_INSTALLER"
}

_workspace_install_download_vmware_fusion() {
	download_link="$VMWARE_FUSION_LINK"
	VMWARE_FUSION_INSTALLER="$DOWNLOAD_DIR/$(basename $download_link)"
	if [ -f $VMWARE_FUSION_INSTALLER ];then
		return
	fi
	_workspace_install_info "Downloading VMware Fusion"
	_workspace_install_info "($download_link)..."
	curl --location --url "$download_link" --output "$VMWARE_FUSION_INSTALLER"
}

_workspace_install_install_workspace() {
	if [ -e $WORKSPACE ];then
		return
	fi
	_workspace_install_info "Installing workspace repo..."
	workspace_dir="$GLOBAL_TEMP_DIR/workspace"
	mkdir -p $workspace_dir
	unzip -q "$DOWNLOAD_DIR/workspace.zip" -d "$workspace_dir"
	mv $workspace_dir/`ls $workspace_dir` "$WORKSPACE"
	rm -rf $workspace_dir
	rm $WORKSPACE_ZIP
	_workspace_install_add_to_bash_profile "export WORKSPACE=\"${WORKSPACE/$HOME/\$HOME}\""
	repo_part_1="${WORKSPACE_REPO#*//}"
	repo_part_2="${repo_part_1#*/}"
	repo_part_3="${repo_part_2#*/}"
	repo_part_4="${repo_part_3#*/}"
	mkdir -p "$WORKSPACE/.system"
	git_remote_repo="${WORKSPACE_REPO%%//*}//${repo_part_1%%/*}/${repo_part_2%%/*}/${repo_part_3%%/*}.git"
	echo "$git_remote_repo" > "$WORKSPACE/.system/upstream-workspace-repo.txt"
	echo "$WORKSPACE_BRANCH" > "$WORKSPACE/.system/upstream-workspace-branch.txt"
	_workspace_install_success "Succesfully downloaded $git_remote_repo to ${WORKSPACE/$HOME/~}"
	_workspace_install_add_to_uninstaller "if _workspace_install_confirm \"Do you want to trash \$WORKSPACE?\";then"
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"\$WORKSPACE\" && echo \"Workspace uninstalled succesfully! (it has moved to your trash can)\""
	_workspace_install_add_to_uninstaller "fi"
}

_workspace_install_install_docker_machine() {
	_workspace_install_info "Installing Docker Machine $DOCKER_MACHINE_VERSION..."
	sudo mv $DOCKER_MACHINE_BINARY /usr/bin/docker-machine
	sudo chmod +x /usr/bin/docker-machine
}

_workspace_install_install_vagrant() {
	_workspace_install_info "Installing Vagrant $VAGRANT_VERSION..."
	mkdir -p "$VAGRANT_HOME"
	_workspace_install_add_to_bash_profile "export VAGRANT_HOME=\"${VAGRANT_HOME/$WORKSPACE/\$WORKSPACE}\""

	_workspace_install_install "$VAGRANT_INSTALLER" "Vagrant"

	if [ "$(which vagrant)" == "" ];then
		_workspace_install_error "Vagrant failed to install."
		return
	fi
	_workspace_install_add_to_uninstaller "if _workspace_install_confirm \"Do you want to uninstall Vagrant?\";then"
	_workspace_install_add_to_uninstaller "if [ -d \$WORKSPACE/.vagrant.d ];then"
	_workspace_install_add_to_uninstaller "cd \"\$WORKSPACE/.vagrant.d}\""
	_workspace_install_add_to_uninstaller "if [ \"\$(which vagrant)\" != \"\" ];then vagrant destroy -f;fi"
	_workspace_install_add_to_uninstaller "fi"
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/opt/vagrant\""
	# _workspace_install_trash the /opt folder if it's empty
	_workspace_install_add_to_uninstaller "if [ -d /opt ] && [ \"\$(ls -A /opt)\" == \"\" ];then sudo rmdir \"/opt\";fi"
	sed -i "" "s/read my_answer/my_answer=\"Yes\"/" "$GLOBAL_TEMP_DIR/uninstall-vagrant.sh"
	sed -i "" "s/key_exit 0/#key_exit 0/" "$GLOBAL_TEMP_DIR/uninstall-vagrant.sh"
	sed -i "" "s/osascript/sudo osascript/" "$GLOBAL_TEMP_DIR/uninstall-vagrant.sh"
	_workspace_install_add_to_uninstaller "$(awk 'FNR>1' $GLOBAL_TEMP_DIR/uninstall-vagrant.sh)"
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$command_location\""
	_workspace_install_add_to_uninstaller "fi"
}

_workspace_install_install_provider() {
	case $PROVIDER in
		virtualbox)
			_workspace_install_install_virtualbox
			_workspace_install_install_virtualbox_extension_pack
			;;
		vmware-fusion)
			_workspace_install_install_vmware_fusion
			;;
	esac
}

_workspace_install_install_virtualbox() {
	_workspace_install_info "Installing VirtualBox..."
	_workspace_install_install "$VIRTUALBOX_INSTALLER" "VirtualBox.app"
	if ! _workspace_install_provider_is_installed "virtualbox";then
		_workspace_install_error "VirtualBox failed to install."
		return
	fi

	sed -i "" "s/my_default_prompt=0/my_default_prompt=\"Yes\"/" "$GLOBAL_TEMP_DIR/uninstall-virtualbox.sh"
	sed -i "" "s/exit 0/#exit 0/" "$GLOBAL_TEMP_DIR/uninstall-virtualbox.sh"
	_workspace_install_add_to_uninstaller "if _workspace_install_confirm 'Do you want to uninstall VirtualBox?';then"
	_workspace_install_add_to_uninstaller "$(awk 'FNR>1' $GLOBAL_TEMP_DIR/uninstall-virtualbox.sh)"
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/VirtualBox VMs\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/org.virtualbox.app\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/VirtualBox\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Saved Application State/org.virtualbox.app.VirtualBox.savedState\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Application Support/VirtualBox\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Python/2.6/site-packages/vboxapi\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Python/2.6/site-packages/vboxapi-1.0-py2.6.egg-_workspace_install_info\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Python/2.7/site-packages/vboxapi\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Python/2.7/site-packages/vboxapi-1.0-py2.7.egg-_workspace_install_info\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Applications/VirtualBox.app\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Applications/VirtualBox.app\""
	_workspace_install_add_to_uninstaller "fi"
}

_workspace_install_install_virtualbox_extension_pack() {
	_workspace_install_info "Installing VirtualBox Extension Pack..."
	_workspace_install_install "$VIRTUALBOX_EXT_PACK_INSTALLER" "VirtualBox Extension Pack"
}

_workspace_install_install_vmware_fusion() {
	_workspace_install_info "Installing VMware Fusion $VMWARE_FUSION_VERSION..."
	_workspace_install_install "$VMWARE_FUSION_INSTALLER" "VMware Fusion.app"
	# osascript -e 'tell application "Finder"' -e 'close front window' -e 'end tell'

	if ! _workspace_install_provider_is_installed "vmware-fusion";then
		_workspace_install_error "VMware Fusion failed to install."
		return
	fi

	_workspace_install_add_to_uninstaller "if _workspace_install_confirm 'Do you want to uninstall VMware Fusion?';then"
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Application Support/VMWare\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Application Support/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Preferences/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Logs/VMWare\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Logs/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Library/Logs/VMWare Fusion Service.log\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Caches/com.vmware.fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/com.vmware.fusionStartMenu.plist\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/com.vmware.fusion.LSSharedFileList.plist\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Preferences/com.vmware.fusion.plist\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Application Support/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Logs/VMWare\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Library/Logs/VMWare Fusion\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"$HOME/Applications/VMware Fusion.app\""
	_workspace_install_add_to_uninstaller "_workspace_install_trash \"/Applications/VMware Fusion.app\""
	_workspace_install_add_to_uninstaller "fi"

	# TODO: fix HGFS issue: echo "answer AUTO_KMODS_ENABLED yes" | sudo tee -a /etc/vmware-tools/locations

	# Check if VMWare has ran a first time before
	if [ ! -d "$HOME/Library/Application Support/VMware Fusion.app" ];then
		if [ -d "$HOME/Applications/VMware Fusion.app" ];then
			vmware_app="$HOME/Applications/VMware Fusion.app"
		elif [ -d "/Applications/VMware Fusion.app" ];then
			vmware_app="/Applications/VMware Fusion.app"
		else
			_workspace_install_error "There was no VMware Fusion.app found on your system"
			return
		fi
		open "$vmware_app"
	fi
}

_workspace_install_provider_is_installed() {
	if [ "$1" == "virtualbox" ];then
		if [ -d "/Applications/VirtualBox.app" ] || [ -d "$HOME/Applications/VirtualBox.app" ];then
			return 0
		fi
	elif [ "$1" == "vmware-fusion" ];then
		if [ -d "/Applications/VMWare Fusion.app" ] || [ -d "$HOME/Applications/VMWare Fusion.app" ];then
			return 0
		fi
	fi
	return 1
}

_workspace_install_provider_nice_name() {
	case $1 in
		virtualbox)
			echo -n "VirtualBox"
			;;
		vmware-fusion)
			echo -n "VMware Fusion"
			;;
		*)
			echo -n "$1"
			;;
	esac
}

_workspace_install_read_environment_file() {
	if [ ! $USERNAME ];then
		echo ""
		[ $YES_TO_ALL ] || read -p "What username to use for your workspace? [$DEFAULT_USERNAME]: " USERNAME
		USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
	fi

	if [ ! $COREOS_RELEASE_CHANNEL ];then
		while [ "$COREOS_RELEASE_CHANNEL" != "stable" ] && [ "$COREOS_RELEASE_CHANNEL" != "beta" ] && [ "$COREOS_RELEASE_CHANNEL" != "alpha" ];do
			echo ""
			echo "CoreOS updates on three release channels (alpha|beta|stable)."
			echo "See https://coreos.com/releases/ for the differences."
			echo "1. Alpha"
			echo "2. Beta"
			echo "3. Stable"
			[ $YES_TO_ALL ] || read -p "On which CoreOS update channel do you want to be? [$DEFAUlT_COREOS_RELEASE_CHANNEL]: " COREOS_RELEASE_CHANNEL
			COREOS_RELEASE_CHANNEL=${COREOS_RELEASE_CHANNEL:-$DEFAUlT_COREOS_RELEASE_CHANNEL}
			case `echo $COREOS_RELEASE_CHANNEL | awk '{print tolower($0)}'` in
				1|alpha)
					COREOS_RELEASE_CHANNEL="alpha"
					;;
				2|beta)
					COREOS_RELEASE_CHANNEL="beta"
					;;
				3|stable)
					COREOS_RELEASE_CHANNEL="stable"
					;;
				*)
					COREOS_RELEASE_CHANNEL=
					;;
			esac
		done
	fi
}

_workspace_install_install_environment_file() {
	_workspace_install_info "Installing environment file..."
	cpus="2"
	memory="1024"
	instances="3"
	network="public"
	if [ "$PROVIDER" == "virtualbox" ];then
		network="private"
	fi
	network_interface="en0: Wi-Fi (Airport)"
	rand_mac_addr="00:$(( ( RANDOM % 89 ) + 10 )):$(( ( RANDOM % 89 ) + 10 )):00:01:01"
	timezone=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
	echo "{" > "$WORKSPACE/env.json"
	echo "  \"coreos-release-channel\": \"$COREOS_RELEASE_CHANNEL\"," >> "$WORKSPACE/env.json"
	echo "  \"cpus\": $cpus," >> "$WORKSPACE/env.json"
	echo "  \"instances\": $instances," >> "$WORKSPACE/env.json"
	echo "  \"memory\": $memory," >> "$WORKSPACE/env.json"
	echo "  \"provider\": \"$PROVIDER\"," >> "$WORKSPACE/env.json"
	echo "  \"network\": \"$network\"," >> "$WORKSPACE/env.json"
	echo "  \"network-interface\": \"$network_interface\"," >> "$WORKSPACE/env.json"
	echo "  \"start-mac-addr\": \"$rand_mac_addr\"," >> "$WORKSPACE/env.json"
	echo "  \"timezone\": \"$timezone\"," >> "$WORKSPACE/env.json"
	echo "  \"username\": \"$USERNAME\"" >> "$WORKSPACE/env.json"
	echo "}" >> "$WORKSPACE/env.json"
}

_workspace_install_add_to_uninstaller() {
	if [ $UPDATE_UNINSTALLER ];then
		if [ "$1" != "" ];then
			addition="$1"
		else
			addition=
			while read -r line
			do
				addition="$addition$line\n"
			done
		fi

		uninstaller_script="$WORKSPACE/.system/uninstall.sh"
		mkdir -p "$(dirname "$uninstaller_script")"
		if [ ! -f "$uninstaller_script" ];then
			echo "#!/bin/bash" > $uninstaller_script
			echo 'source $HOME/.bash_profile' >> $uninstaller_script
			type _workspace_install_trash | tail -n +2 >> $uninstaller_script
			echo "" >> $uninstaller_script
			type _workspace_install_confirm | tail -n +2 >> $uninstaller_script
			echo "" >> $uninstaller_script
			type _workspace_install_uninstall_bash_profile_lines | tail -n +2 >> $uninstaller_script
			echo "_workspace_install_uninstall_bash_profile_lines" >> $uninstaller_script
			chmod u+x "$uninstaller_script"
		fi
		
		echo -e "${addition//$HOME/\$HOME}\n" >> "$uninstaller_script"
	fi
}

_workspace_install_add_to_bash_profile() {
	bash_profile_file="$HOME/.bash_profile"
	if [ -f $bash_profile_file ];then
		bash_content="$(cat $bash_profile_file)"
		if [ "${bash_content/$1/}" != "$bash_content" ];then
			return
		fi
	fi
	bash_profile_suffix_line="# === auto-added by workspace installation ==="
	echo "$1 $bash_profile_suffix_line" >> $bash_profile_file
}

_workspace_install_uninstall_bash_profile_lines() {
	bash_profile_file="$HOME/.bash_profile"
	bash_profile_suffix_line="# === auto-added by workspace installation ==="
	if [ -f "$bash_profile_file" ];then
		new_bash_profile_file=""
		while read line;do
			if [ "${line/"$bash_profile_suffix_line"/}" != "$line" ];then
				continue
			fi
			new_bash_profile_file="$new_bash_profile_file\n$line"
		done < $bash_profile_file

		if [ ! -n "$new_bash_profile_file" ];then
			if [ -f "$bash_profile_file" ];then
				rm "$bash_profile_file"
			fi
		else
			echo -e "$new_bash_profile_file" > $bash_profile_file
		fi

		if [ "$(cat $bash_profile_file)" == "" ];then
			rm "$bash_profile_file"
		fi
	fi
}

_workspace_install_confirm() {
	res=
	if [ $YES_TO_ALL ];then
		return 0
	fi
	while [ "$res" != "y" ] && [ "$res" != "n" ];do
		read -p "$1 [Y/n]: " res
		if [ "$res" == "" ];then
			res="y"
		fi
		res=`echo $res | awk '{print tolower($0)}'`
	done
	if [ "$res" != "y" ];then
		return 1
	fi
}

_workspace_install_trash() {
	if [ -f "$1" ] || [ -d "$1" ];then
		trash_file="$HOME/.Trash/$(basename "$1")-$(date +"%y-%m-%d_%H;%M;%S").bak"
		owner=`ls -ld "$1" | awk '{print $3}'`
		if [ "$owner" == "$(whoami)" ];then
			mv -f "$1" "$trash_file"
		else
			sudo mv -f "$1" "$trash_file"
		fi
		sleep 2
	fi
}

# === Download and install scripts: ================================

_workspace_install_info() {
    printf "\e[0;36m" # turquase
    echo -e "☝️  $1"
    printf "\e[0m"
}

_workspace_install_success() {
    printf "\e[0;32m" # green
    echo -e "👍  $1"
    printf "\e[0m"
}

_workspace_install_warning() {
    printf "\e[0;33m" # orange
    echo -e "😟  $1"
    printf "\e[0m"
}

_workspace_install_error() {
    printf "\e[0;31m" # red
    echo -e "😓  $1"
    printf "\e[0m"
}

_workspace_install_version() {
	version="$($1 --version | sed -n 1p)"
	if [ "$version" == "" ];then
		version="$($1 version | sed -n 1p)"
	fi
	capital=$(echo $1 | head -c 1 | tr [a-z] [A-Z]; echo $1 | tail -c +2)
	version="${version/$capital/}"
	version="${version/$1/}"
	version="${version/v/}"
	version="${version/V/}"
	version="${version/version/}"
	version="${version/Version/}"
	version="${version/ /}"
	echo "$version"
}

_workspace_install_install() {
	package="$1"
	application_name="$2"

	filename=$(basename "$package")
	extension="${filename##*.}"

	volume_name="$application_name"
	volume_name="${volume_name%.*}"
	volume_name="${volume_name// /-}"
	volume_name="$(echo $volume_name | awk '{print tolower($0)}')"
	extraction_path="$GLOBAL_TEMP_DIR/${filename%.*}-extraction-$(date +%s)"
	mkdir -p "$extraction_path"


	case "$extension" in
		dmg)
			volume_path="/Volumes/$volume_name"
			hdiutil attach -mountpoint "$volume_path" "$package"
			_workspace_install_info "Copying DMG content to $extraction_path. Please wait a sec..."
			ls -1 "$volume_path" | while read file;do
				if [ "$file" == "Applications" ];then
					continue
				fi
				cp -rf "$volume_path/$file" "$extraction_path/$file"
			done
			_workspace_install_info "Detaching $volume_path"
			hdiutil detach "$volume_path"
			;;
		zip)
			unzip -q -o "$package" -d "$extraction_path"
			;;
		gz|bz2|tgz)
			if [ -d "$extraction_path" ];then
				rm -rf "$extraction_path"
			fi
			case "$extension" in
				gz|tgz)
					method="z"
					;;
				bz2)
					method="b"
					;;
			esac
			temp_dir=$GLOBAL_TEMP_DIR/extraction
			mkdir -p $temp_dir
			tar -xv${method}f "$package" --directory $temp_dir
			mv $temp_dir/`ls temp_dir` "$extraction_path"
			rm -rf $temp_dir
			;;
		vbox-extpack)
			open "$package"
			;;
		?)
			echo ""
			_workspace_install_error "Unable to install $extension files"
			[ $YES_TO_ALL ] || read -p "Press 'Enter/Return' to proceed. "
			return
			;;
	esac

	application_path="Applications"
	dest_application_path="/$application_path"
	app_path=""
	pkg="$(ls $extraction_path | grep .pkg | head -1)"
	app="$(ls $extraction_path | grep .app | head -1)"
	if [ "$pkg" != "" ];then
		_workspace_install_info "Installing package $extraction_path/$pkg..."
		sudo installer -verboseR -pkg "$extraction_path/$pkg" -target /
		uninstall_script="$(ls $extraction_path | grep .tool | head -1)"
		if [ "$uninstall_script" != "" ];then
			cp -f "$extraction_path/$uninstall_script" "$GLOBAL_TEMP_DIR/uninstall-$volume_name.sh"
		fi
		app_path="$dest_application_path/$application_name"
	elif [ "$app" != "" ];then
		app_path="$extraction_path/$app"
	fi

	# VirtualBox needs to be located at /Applications
	if [ "$application_name" == "VirtualBox.app" ];then
		return
	fi

	if [ -d "$HOME/$application_path" ];then
		dest_application_path="$HOME/$application_path"
	fi


	# -- Move to home Applications directory if there is one ------------------------
	if [ "$app_path" != "" ] && [ -d "$app_path" ];then
		dest_app_path="$dest_application_path/$(basename "$app_path")"
		if [ "$app_path" != "$dest_app_path" ];then
			echo "Moving $app_path to $dest_app_path..."
			sudo mv -f "$app_path" "$dest_app_path"
		fi
	fi
}

_workspace_install_find_download_link() {
	downloads_link="$1"
	download_link_base_pattern="$2"
	requested_version="$3"
	download_link_base_front=""
	download_link_base_rear=""
	latest_version=""

	IFS='*' read -ra str <<< "$download_link_base_pattern"
	for i in "${str[@]}";do
	    if [ "$download_link_base_front" == "" ];then
	    	download_link_base_front="$i"
	    elif [ "$download_link_base_rear" == "" ];then
	    	download_link_base_rear="$i"
	    fi
	done

	find_download_link_html=$(curl --location --silent --url "$downloads_link")
	find_download_link_html="${find_download_link_html//href=\"/ }"
	find_download_link_html="${find_download_link_html//$download_link_base_rear/$download_link_base_rear }"
	for s in $find_download_link_html;do
		if [ "${s%$download_link_base_rear}" != "$s" ];then
			file_name="$(basename $s)"
			latest_version="${file_name/${download_link_base_front}_/}"
			latest_version="${latest_version/${download_link_base_front}-/}"
			latest_version="${latest_version/${download_link_base_front}/}"
			latest_version="${latest_version/_${download_link_base_rear}/}"
			latest_version="${latest_version/-${download_link_base_rear}/}"
			latest_version="${latest_version/${download_link_base_rear}/}"
			if [ "$latest_version" == "master" ];then
				continue
			fi
			if [ $requested_version ];then
				s="${s//$latest_version/$requested_version}"
			fi
			if [ "${s:0:1}" == "/" ] && [ "${s:0:2}" != "//" ];then
				domain_name=$(echo $downloads_link | cut -d'/' -f3)
				s="http://${domain_name}${s}"
			fi
			echo "$s"
			return
		fi
	done
}

_workspace_install_start
