#!/bin/bash

#WORKSPACE_REPO="https://github.com/crobays/workspace/archive/master.zip"
WORKSPACE_REPO="http://gitlab.userx.nl/crobays/workspace/repository/archive.zip?ref=master"
VMWARE_FUSION_DMG_LINK="https://download3.vmware.com/software/fusion/file/VMware-Fusion-6.0.4-1887983.dmg"
SILENT_LEVEL=1 # 0 = none, 1 = only downloads, 2 = all requests
DOWNLOADS_DIRECTORY="$HOME/Downloads"
PROVIDER="$1"
PROVIDER="${PROVIDER//_/-}"
WORKSPACE="${2:-$HOME/workspace}"
update_uninstaller=1

function start ()
{
	echo "Administrator privileges are required for some operations..."
	sudo echo ""
	uninstall_previous_workspace

	if [ "$PROVIDER" == "" ]
	then
		if [ -d "/Applications/VMWare Fusion.app" ] || [ -d "$HOME/Applications/VMWare Fusion.app" ]
		then
			PROVIDER="vmware-fusion"
		else
			PROVIDER="virtualbox"
		fi
	elif [ "$PROVIDER" != "virtualbox" ] && [ "$PROVIDER" != "vmware-fusion" ]
	then
		error "Invalid provider: $PROVIDER: use virtualbox or vmware-fusion"
		exit
	fi

	success 'Installation Started'
	set_up_workspace
	add_shell_profile_to_bash_profile

	if [ ! -d "/Applications/Vagrant" ] && [ ! -d "$HOME/Applications/Vagrant" ]
	then
		install_vagrant
	fi

	if [ "$PROVIDER" == "virtualbox" ] && [ ! -d "/Applications/VirtualBox.app" ]
	then
		install_virtualbox
	elif [ "$PROVIDER" == "vmware-fusion" ] && [ ! -d "/Applications/VMWare Fusion.app" ] && [ ! -d "$HOME/Applications/VMWare Fusion.app" ]
	then
		install_vmware_fusion
	fi
	add_projects
}

function uninstall_previous_workspace ()
{
	if [ -f "$WORKSPACE/.system/uninstall.sh" ]
	then
		info "Found uninstaller... Trashing old workspace files..."
		sudo bash "$WORKSPACE/.system/uninstall.sh"
		info "Old Workspace uninstalled"
		sleep 5
		info "Installing new Workspace..."
	fi
}

# --- ask workspace directory ---------------------------------------------------

function set_up_workspace()
{
	# Save hostname, username and timezone
	timezone="$(sudo systemsetup -gettimezone)"
	timezone="${timezone/Time Zone: /}"
	hostname="$(hostname)"

	if [ -d "$WORKSPACE" ]
	then
		echo "${WORKSPACE/$HOME/~} already exists. Remove or choose another directory."
		exit
	fi

	echo "-- Workspace start --"

	mkdir -p "$WORKSPACE"

	if [ ! -d "$WORKSPACE" ]
	then
		error "No permission to create $WORKSPACE"
		exit
	fi

	# --- download base files ---------------------
	silent_flag=""
	if [ $SILENT_LEVEL -gt 1 ]
	then
		silent_flag="--silent"
	fi
	curl --location $silent_flag --url "$WORKSPACE_REPO" --output "$DOWNLOADS_DIRECTORY/vagrant-workspace.zip"
	unzip "$DOWNLOADS_DIRECTORY/vagrant-workspace.zip" -d "$WORKSPACE"
	rm "$DOWNLOADS_DIRECTORY/vagrant-workspace.zip"
	remove_sub_dir "$WORKSPACE"
	add_to_uninstaller "trash \"$WORKSPACE\""
	cp -r "$WORKSPACE/config-boilerplate" "$WORKSPACE/config"
	rand_mac_addr="00:$(( ( RANDOM % 89 ) + 10 )):00:00:00:01"
	echo -e "{\n\t\"username\": \"$USER\",\n\t\"hostname\": \"${hostname%.*}\",\n\t\"timezone\": \"$timezone\",\n\t\"provider\": \"$PROVIDER\",\n\t\"memory\": 512,\n\t\"cpus\": 1,\n\t\"network\": \"private\",\n\t\"network-interface\": false,\n\t\"start-mac-addr\": \"$rand_mac_addr\"\n}" > "$WORKSPACE/env.json"

	echo "-- Workspace end --"
}

function add_projects ()
{
	echo "-- Projects start --"

	mkdir -p "$WORKSPACE/projects" && success "Added projects directory"

	echo "-- Projects end --"
}

function add_to_uninstaller ()
{
	if [ $update_uninstaller ]
	then
		if [ "$1" != "" ]
		then
			addition="$1"
		else
			addition=""
			while read -r line
			do
				addition="$addition$line\n"
			done
		fi
		uninstaller_script="$WORKSPACE/.system/uninstall.sh"
		mkdir -p "$(dirname "$uninstaller_script")"
		if [ ! -f "$uninstaller_script" ]
		then
			echo -e "#!/bin/bash\ntrash() {\n\tif [ -f \"\$1\" ] || [ -d \"\$1\" ]\n\tthen\n\t\tsudo mv -f \"\$1\" \"\$HOME/.Trash/\$(basename \"\$1\")-\$(date +\"%y-%m-%d_%H;%M;%S\").bak\"\n\t\tsleep 2\n\tfi\n}\n" > "$uninstaller_script"
			chmod +x "$uninstaller_script"
		fi
		
		uninstaller="$(cat "$uninstaller_script")"
		if [ "${uninstaller//$addition/}" == "$uninstaller" ]
		then
			echo -e "${addition//$HOME/\$HOME}\n" >> "$uninstaller_script"
		fi
	fi
}

function add_shell_profile_to_bash_profile ()
{
	# Add coreos alias to bash_profile file
	bash_profile_file="$HOME/.bash_profile"
	start_line="# === Workspace aliases start ==="
	end_line="# === Workspace aliases end ==="
	add_bash_line="$start_line\nexport WORKSPACE=\"${WORKSPACE/$HOME/\$HOME}\"\nalias coreos=\"cd \$WORKSPACE && \$WORKSPACE/coreos\"\nalias workspace=\"cd \$WORKSPACE && \$WORKSPACE/coreos -c workspace\"\n$end_line"
	if [ -f "$bash_profile_file" ]
	then
		bash_profile="$(cat "$bash_profile_file")"
		if [ "${bash_profile/$add_bash_line/}" == "$bash_profile" ]
		then
			add_line=1
		fi
	else
		add_line=1
	fi

	if [ add_line ]
	then
		echo -e "$add_bash_line" >> "$bash_profile_file"

		add_to_uninstaller << EOF
			if [ -f "$bash_profile_file" ]
			then
				echo -e "\\\n" >> $bash_profile_file
				new_bash_profile_file=""
				while read line
				do
					if [ ! \$write_line ] && [ "\$line" != "" ]
					then
						write_line="yes"
					fi

					if [ ! \$write_line ]
					then
						continue
					fi

					if [ "\$line" == "$start_line" ]
					then
						write_line="no"
					fi
					
					if [ "\$write_line" == "yes" ]
					then
						new_bash_profile_file="\$new_bash_profile_file\$line\\\n"
					fi
							
					if [ "\$line" == "$end_line" ]
					then
						write_line="yes"
					fi

				done < $bash_profile_file

				if [ ! -n "\$new_bash_profile_file" ]
				then
					if [ -f "$bash_profile_file" ]
					then
						rm "$bash_profile_file"
					fi
				else
					echo -e "\$new_bash_profile_file" > $bash_profile_file
				fi
			fi
EOF
	fi

	source "$bash_profile_file"
}

function install_vagrant ()
{
	# -- install Vagrant ------------------------------------------------------------
	application_name="Vagrant"
	command="vagrant"
	download_and_install \
		"$command" \
		"http://www.vagrantup.com/downloads" \
		"vagrant*.dmg" \
		"" \
		"$application_name"

	command_location="$(which $command)"
	if [ -d "$HOME/Applications" ]
	then
		sudo mv -f "/Applications/$application_name" "$HOME/Applications/$application_name"
		sudo ln -sf "$HOME/Applications/$application_name/bin/$command" "$command_location"
		add_to_uninstaller "trash \"$HOME/Applications/$application_name\""
	fi

	sed -i "" "s/read my_answer/my_answer=\"Yes\"/" "$WORKSPACE/.system/uninstall-vagrant.sh"
	sed -i "" "s/key_exit 0/#key_exit 0/" "$WORKSPACE/.system/uninstall-vagrant.sh"
	add_to_uninstaller "$(awk 'FNR>1' $WORKSPACE/.system/uninstall-vagrant.sh)"
	rm -rf "$WORKSPACE/.system/uninstall-vagrant.sh"

	add_to_uninstaller "trash \"$HOME/.vagrant.d\""
	add_to_uninstaller "trash \"$command_location\""
}

function install_virtualbox ()
{
	# -- install VirtualBox ------------------------------------------------------------
	virtual_box_downloads_link="https://www.virtualbox.org/wiki/Downloads"
	download_and_install \
		"" \
		"$virtual_box_downloads_link" \
		"VirtualBox*-OSX.dmg" \
		"" \
		"VirtualBox.app"

	download_and_install \
		"" \
		"$virtual_box_downloads_link" \
		"Oracle_VM_VirtualBox_Extension_Pack-*.vbox-extpack" \
		"" \
		"VirtualBox Extension Pack"

	sed -i "" "s/my_default_prompt=0/my_default_prompt=\"Yes\"/" "$WORKSPACE/.system/uninstall-virtualbox.sh"
	sed -i "" "s/exit 0/#exit 0/" "$WORKSPACE/.system/uninstall-virtualbox.sh"
	add_to_uninstaller "$(awk 'FNR>1' $WORKSPACE/.system/uninstall-virtualbox.sh)"
	rm -rf "$WORKSPACE/.system/uninstall-virtualbox.sh"

	add_to_uninstaller "trash \"$HOME/VirtualBox VMs\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/org.virtualbox.app\""
	add_to_uninstaller "trash \"$HOME/Library/VirtualBox\""
	add_to_uninstaller "trash \"$HOME/Library/Saved Application State/org.virtualbox.app.VirtualBox.savedState\""
	add_to_uninstaller "trash \"/Library/Application Support/VirtualBox\""
	add_to_uninstaller "trash \"/Library/Python/2.6/site-packages/vboxapi\""
	add_to_uninstaller "trash \"/Library/Python/2.6/site-packages/vboxapi-1.0-py2.6.egg-info\""
	add_to_uninstaller "trash \"/Library/Python/2.7/site-packages/vboxapi\""
	add_to_uninstaller "trash \"/Library/Python/2.7/site-packages/vboxapi-1.0-py2.7.egg-info\""
}

function install_vmware_fusion ()
{
	# -- install VMWare Fusion ------------------------------------------------------------
	dest="$DOWNLOADS_DIRECTORY/$(basename $VMWARE_FUSION_DMG_LINK)"
	application_name="VMware Fusion.app"
	echo "-- $application_name start --"

	if [ ! -f "$dest" ]
	then
		download \
			"$VMWARE_FUSION_DMG_LINK" \
			"$dest" \
			"$application_name"
	fi
	install \
		"" \
		"$dest" \
		"$application_name"

	if [ -d "$HOME/Applications" ]
	then
		sudo mv -f "/Applications/$application_name" "$HOME/Applications/$application_name"
		add_to_uninstaller "trash \"$HOME/Applications/$application_name\""
	fi

	add_to_uninstaller "trash \"/Library/Application Support/VMWare\""
	add_to_uninstaller "trash \"/Library/Application Support/VMWare Fusion\""
	add_to_uninstaller "trash \"/Library/Preferences/VMWare Fusion\""
	add_to_uninstaller "trash \"/Library/Logs/VMWare\""
	add_to_uninstaller "trash \"/Library/Logs/VMWare Fusion\""
	add_to_uninstaller "trash \"/Library/Logs/VMWare Fusion Service.log\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/VMWare Fusion\""
	add_to_uninstaller "trash \"$HOME/Library/Caches/com.vmware.fusion\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/VMWare Fusion\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/com.vmware.fusionStartMenu.plist\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/com.vmware.fusion.LSSharedFileList.plist\""
	add_to_uninstaller "trash \"$HOME/Library/Preferences/com.vmware.fusion.plist\""
	add_to_uninstaller "trash \"$HOME/Library/Application Support/VMWare Fusion\""
	add_to_uninstaller "trash \"$HOME/Library/Logs/VMWare\""
	add_to_uninstaller "trash \"$HOME/Library/Logs/VMWare Fusion\""

	echo "-- $application_name end --"
	# TODO: fix HGFS issue: echo "answer AUTO_KMODS_ENABLED yes" | sudo tee -a /etc/vmware-tools/locations
}

# === Download and install scripts: ================================

black="\e[0;30m"
red="\e[0;31m"
green="\e[0;32m"
orange="\e[0;33m"
blue="\e[0;34m"
purple="\e[0;35m"
turquase="\e[0;36m"
NC="\e[0m"

function info ()
{
	printf "$turquase"
	echo "$1"
	printf "$NC"
}

function success ()
{
	printf "$green"
	echo "$1"
	printf "$NC"
}

function error ()
{
	printf "$red"
	echo "$1"
	printf "$NC"
}

function download_and_install ()
{
	command="$1"
	downloads_link="$2"
	download_link_base_pattern="$3"
	specific_version="$4"
	application_name="$5"

	function version()
	{
		version="$($1 --version | sed -n 1p)"
		if [ "$version" == "" ]
		then
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

	if [ "$downloads_link" == "" ]
	then
		echo "Missing second argument: downloads link"
		exiting="yes"
	fi

	if [ "$download_link_base_pattern" == "" ]
	then
		echo "Missing third argument: download link pattern"
		exiting="yes"
	fi

	if [ "$exiting" == "yes" ]
	then
		exit
	fi

	if [ "$application_name" == "" ] && [ "$command" != "" ]
	then
		application_name=$(echo $command | head -c 1 | tr [a-z] [A-Z]; echo $1 | tail -c +2)
	fi

	echo "-- $application_name start --"

	install=""
	if [ "$command" != "" ]
	then
		if [ "$(which $command)" == "" ]
		then
			echo "$application_name not installed"
			install="yes"
		else
			current_version="$(version $command)"
			echo "Current $application_name version: $current_version"
		fi
	fi

	info "Fetching downloads page $downloads_link..."
	download_link="$(find_download_link "$downloads_link" "$download_link_base_pattern")"
	if [ "$download_link" == "" ]
	then
		error "No download link found on $downloads_link"
	else
		if [ "$latest_version" != "" ]
		then
			info "Latest $application_name version: $latest_version ($downloads_link)"

			download_version="$latest_version"

			if [ "$specific_version" != "" ]
			then
				download_version="$specific_version"
				download_link="${download_link//$latest_version/$download_version}"
				info "Forcing $application_name version: $specific_version";
			fi

			if [ "$current_version" != "$download_version" ]
			then
				install="yes"
			fi
		else
			install="yes"
		fi

		if [ "$install" == "yes" ]
		then
			if [ "${download_link:0:1}" == "/" ] && [ "${download_link:0:2}" != "//" ]
			then
				domain_name=$(echo $downloads_link | cut -d'/' -f3)
				download_link="$domain_name$download_link"
			fi
			dest="$DOWNLOADS_DIRECTORY/$(basename $download_link)"
			sudo mkdir -p $(dirname $DOWNLOADS_DIRECTORY)
			if [ ! -f "$dest" ]
			then
				download \
					"$download_link" \
					"$dest" \
					"$application_name"
			fi
			install \
				"$command" \
				"$dest" \
				"$application_name"
		elif [ "$current_version" != "" ]
		then
			success "$application_name already on latest version: $current_version"
		else
			success "$application_name already installed"
		fi
		info "Downloaded $download_link"
	
	fi

	echo "-- $application_name end --"
}

function download()
{
	download_link="$1"
	dest="$2"
	application_name="$3"

	minus_one="-1"	
	if [ "${dest:$minus_one:1}" == "/" ]
	then
		dest="$dest$(basename $download_link)"
	fi

	if [ -f "$dest" ]
	then
		rm -rf "$dest"
	fi

	info "Downloading latest $application_name $download_link..."
	silent_flag=""
	if [ $SILENT_LEVEL -gt 0 ]
	then
		silent_flag="--silent"
	fi
	curl --location $silent_flag --output "$dest" --url "$download_link"
}

function install()
{
	command="$1"
	package="$2"
	application_name="$3"

	filename=$(basename "$package")
	extension="${filename##*.}"

	volume_name="$application_name"
	volume_name="${volume_name%.*}"
	volume_name="${volume_name// /-}"
	volume_name="$(echo $volume_name | awk '{print tolower($0)}')"
	extraction_path="$HOME/${filename%.*}-extraction"
	mkdir -p "$extraction_path"
	usr="/usr/local"
	sudo mkdir -p "$usr"

	case "$extension" in
		dmg)
			volume_path="/Volumes/$volume_name"
			hdiutil attach -mountpoint "$volume_path" "$package"
			osascript -e 'tell application "Finder"' -e 'close front window' -e 'end tell'
			echo "Please wait a sec..."
			sudo cp -rf $volume_path/* $extraction_path/
			hdiutil detach "$volume_path"
			;;
		zip)
			if [ "$(which apt-get)" != "" ]
	    	then
	    		apt-get install unzip
			fi
			
			unzip -o "$package" -d "$extraction_path"
			;;
		gz|bz2)
			if [ -d "$extraction_path" ]
			then
				rm -rf "$extraction_path"
			fi
			case "$extension" in
				gz)
					method="z"
					;;
				bz2)
					method="b"
					;;
			esac
			tar "xfv$method" "$package" --directory "$extraction_path"
			remove_sub_dir "$extraction_path"
			;;
		vbox-extpack)
			cp -f "$package" "$WORKSPACE/.system/$(basename "$package")" 
			;;
		?)
			error "Unable to install $extension-files"
			exit
			;;
	esac

	application_path="Applications"
	dest_application_path="/$application_path"
	app_path=""
	pkg="$(ls $extraction_path | grep .pkg | head -1)"
	app="$(ls $extraction_path | grep .app | head -1)"
	if [ "$pkg" != "" ]
	then
		sudo installer -verboseR -pkg "$extraction_path/$pkg" -target /
		uninstall_script="$(ls $extraction_path | grep .tool | head -1)"
		if [ "$uninstall_script" != "" ]
		then
			sudo cp -f "$extraction_path/$uninstall_script" "$WORKSPACE/.system/uninstall-$volume_name.sh"
			sudo chmod +x "$WORKSPACE/.system/uninstall-$volume_name.sh"
		fi
		app_path="$dest_application_path/$application_name"
	elif [ "$app" != "" ]
	then
		app_path="$extraction_path/$app"
	fi

	# -- Move to home Applications directory if there is one ------------------------
	if [ "$app_path" != "" ] && [ -d "$app_path" ]
	then
		dest_app_path="$dest_application_path/$(basename "$app_path")"
		if [ "$app_path" != "$dest_app_path" ]
		then
			sudo mv -f "$app_path" "$dest_app_path"
		fi

		success "$application_name installed."
		add_to_uninstaller "trash \"$dest_app_path\""
	fi

	if [ "$command" != "" ]
	then
		if [ -d "$extraction_path/bin" ]
		then
			sudo mv -f "$extraction_path" "$usr/$command"
			export PATH="$PATH:$usr/$command/bin"
		else
			sudo mkdir -p "$usr/bin"
			sudo mv $extraction_path/* "$usr/bin/"
		fi

		if [ "$(which $command)" != "" ]
		then
			success "$application_name $(version $command)"
		else
			error "Something went wrong installing $application_name"
		fi
	fi
	
	if [ -d "$extraction_path" ]
	then
		sudo rm -rf "$extraction_path"
	fi
}

function find_download_link()
{
	downloads_link="$1"
	download_link_base_pattern="$2"
	download_link_base_front=""
	download_link_base_rear=""
	latest_version=""

	IFS='*' read -ra str <<< "$download_link_base_pattern"
	for i in "${str[@]}"
	do
	    if [ "$download_link_base_front" == "" ]
	    then
	    	download_link_base_front="$i"
	    elif [ "$download_link_base_rear" == "" ]
	    then
	    	download_link_base_rear="$i"
	    fi
	done
	silent_flag=""
	silent_flag=""
	if [ $SILENT_LEVEL -gt 1 ]
	then
		silent_flag="--silent"
	fi

	# Find download link
	find_download_link_html=$(curl --location $silent_flag --url "$downloads_link")
	find_download_link_html="${find_download_link_html//href=\"/ }"
	find_download_link_html="${find_download_link_html//$download_link_base_rear/$download_link_base_rear }"
	for s in $find_download_link_html
	do
		if [ "${s%$download_link_base_rear}" != "$s" ]
		then
			file_name="$(basename $s)"
			latest_version="${file_name/${download_link_base_front}_/}"
			latest_version="${latest_version/${download_link_base_front}-/}"
			latest_version="${latest_version/${download_link_base_front}/}"
			latest_version="${latest_version/_${download_link_base_rear}/}"
			latest_version="${latest_version/-${download_link_base_rear}/}"
			latest_version="${latest_version/${download_link_base_rear}/}"
			if [ "$latest_version" == "master" ]
			then
				continue
			fi
			echo "$s"
			return
		fi
	done
}

# Removes a directory which is in between two directories: /home/subdir/directory becomes /home/directory
function remove_sub_dir ()
{
	if [ ! -d "$1" ]
	then
		error "$1 is not a directory"
		exit
	fi
	count=$(ls -1A "$1" | wc -l)
	if [ $count -eq 1 ]
	then
		remove_sub_dir_dir="$1/$(ls "$1")"
		if [ ! -d "$remove_sub_dir_dir" ]
		then
			echo "$remove_sub_dir_dir is not a directory"
			exit
		fi
		ls -1A "$remove_sub_dir_dir" | while read -r file
		do
		    mv "$remove_sub_dir_dir/$file" "$remove_sub_dir_dir/../"
		done
		rmdir "$remove_sub_dir_dir"
	else
		echo "$count items in $1"
		exit
	fi
}

start
