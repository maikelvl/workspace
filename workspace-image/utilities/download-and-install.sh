#!/bin/bash
DOWNLOADS_DIRECTORY="/downloads"
SILENT_LEVEL=2

# === Download and install scripts: ================================

black="\e[0;30m"
red="\e[0;31m"
green="\e[0;32m"
orange="\e[0;33m"
blue="\e[1;34m"
purple="\e[0;35m"
turquase="\e[0;36m"
NC="\e[0m"

function info ()
{
    printf "$turquase"
    echo "$1"
    printf "$NC"
}

function ask ()
{
    printf "$blue"
    if [ "$1" == "-n" ]
    then
    	echo -n "$2"
	else
		echo "$1"
	fi
    printf "$NC"
}

function success ()
{
    printf "$green"
    echo "$1"
    printf "$NC"
}

function warning ()
{
    printf "$orange"
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
	download_link="$(find_download_link "$downloads_link" "$download_link_base_pattern" "$specific_version")"
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

			if [ $REMOVE_DOWNLOAD_AFTER_INSTALL ]
			then
				rm -rf "$dest"
			fi
		elif [ "$current_version" != "" ]
		then
			info "$application_name already on latest version: $current_version"
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
		mkdir -p "$dest"
		dest="$dest$(basename $download_link)"
	else
		mkdir -p "$(dirname $dest)"
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
	if [ -d "$extraction_path" ]
	then
		rm -rf "$extraction_path"
	fi
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
			case "$extension" in
				gz)
					method="z"
					;;
				bz2)
					method="b"
					;;
			esac
			tar xfv$method "$package" --directory "$extraction_path"
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
	version="$3"

	if [ "$version" != "" ]
	then
		version="$version."
	fi
	escaped_version="${version//./\\.}"
	download_link_base_pattern="${download_link_base_pattern//./\\.}"
	download_link_base_pattern="${download_link_base_pattern/\*/$escaped_version([0-9]+\.?)*}"

	silent_flag=""
	if [ $SILENT_LEVEL -gt 1 ]
	then
		silent_flag="--silent"
	fi
	
	links="$(curl --location $silent_flag --url $downloads_link | awk -v RS='<a' "/ href=\".*?$download_link_base_pattern\"/{ print \$1, \$2, \$3 }" | sort)"
	# echo "$links"
	new_links=""
	for link in $links
	do
		if [ "${link/href=\"/}" == "$link" ]
		then
			continue
		fi
		link="$(echo "$link" | sed -rn 's/href="([^"]*)"(.*)/\1/p')"
		sort_link="$(echo "$link" | sed -rn 's/([\.0-9]*[\.0-9])/\10.0.0.0./p')"
		new_links="$(echo -e "$new_links\n$sort_link $link")"
	done
	# echo "$new_links" | sort
	last_item=""
	for link in $(echo "$new_links" | sort)
	do
		last_item="$link"
	done

	link=${last_item/\#/}
	
	if [ "$link" == "" ]
	then
		return
	fi

	if [ "${link/\/\//}" == "$link" ]
	then
		link="$downloads_link$link"
	fi
	
	echo $link
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
