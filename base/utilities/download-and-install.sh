#!/bin/bash
DOWNLOADS_DIRECTORY="/downloads"
SILENT="no"

# === Download and install scripts: ================================

download_and_install ()
{
	command="$1"
	downloads_link="$2"
	download_link_pattern="$3"
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
	if [ "$download_link_pattern" == "" ]
	then
		echo "Missing third argument: download link pattern"
		exiting="yes"
	fi

	if [ "$exiting" == "yes" ]
	then
		exit
	fi

	if [ "$application_name" == "" ] && [ "$command" != "" ];then
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

	echo "Fetching downloads page: $downloads_link..."
	download_link="$(find_download_link "$downloads_link" "$download_link_pattern")"
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
			mkdir -p $(dirname $DOWNLOADS_DIRECTORY)
			if [ ! -f "$dest" ]
			then
				download "$application_name" "$download_link" "$dest"
			fi
			install "$dest" "$application_name"
		elif [ "$current_version" != "" ]
		then
			success "$application_name already on latest version: $current_version"
		else
			success "$application_name already installed"
		fi
		info "Download link: $download_link"
	
	fi

	echo "-- $application_name end --"
}

download()
{
	application_name="$1"
	download_link="$2"
	dest="$3"

	minus_one="-1"	
	if [ "${dest:$minus_one:1}" == "/" ];then
		dest="$dest$(basename $download_link)"
	fi

	if [ -f "$dest" ]
	then
		rm -rf "$dest"
	fi

	info "Downloading latest $application_name $download_link..."
	if [ "$SILENT" == "yes" ]
	then
		silent_flag="--silent"
	fi
	curl --location $silent_flag --output "$dest" --url "$download_link"
}

install()
{
	package="$1"
	application_name="$2"

	filename=$(basename "$package")
	extension="${filename##*.}"

	volume_name="$application_name"
	volume_name="${volume_name%.*}"
	volume_name="${volume_name// /-}"
	volume_name="$(echo $volume_name | awk '{print tolower($0)}')"
	extraction_path="$HOME/$volume_name-extraction"
	usr="/usr/local"
	sudo mkdir -p "$usr"

	case "$extension" in
		dmg)
			volume_path="/Volumes/$volume_name"
			hdiutil attach -mountpoint "$volume_path" "$package"
			pkg="$(ls $volume_path/*.pkg)"
			if [ "$pkg" != "" ]
			then
				sudo installer -verboseR -pkg "$pkg" -target /
			fi
			hdiutil detach "$volume_path"
			if [ "$pkg" == "" ]
			then
				error "No package found in $volume_path: $pkg"
				exit
			fi
			;;
		zip)
			if [ "$(which apt-get)" != "" ]
	    	then
	    		apt-get install unzip
			fi
			mkdir "$extraction_path"
			unzip -o "$package" -d "$extraction_path"
			;;
		gz|bz2)
			if [ -d "$extraction_path" ]
			then
				rm -rf "$extraction_path"
			fi
			mkdir "$extraction_path"
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
			cp -f "$package" "$WORKSPACE/.extension.vbox-extpack" 
			return
			;;
		?)
			error "Unable to install $extension-files"
			exit
			;;
	esac

	if [ "$command" != "" ]
	then
		if [ -d "$extraction_path/bin" ]
		then
			mv -f "$extraction_path" "$usr/$command"
			export PATH="$PATH:$usr/$command/bin"
		else
			mkdir -p "$usr/bin"
			mv $extraction_path/* "$usr/bin/"
		fi

		if [ "$(which $command)" != "" ]
		then
			success "$application_name $(version $command) installed"
		else
			error "Something went wrong installing $application_name"
		fi
	fi

	# -- Move to home Applications directory if there is one ------------------------
	if [ "$application_name" != "" ]
	then
		if [ -d "$HOME/Applications" ] && [ -d "/Applications/$application_name" ]
		then
			command_location=""
			if [ "$command" != "" ] && [ "$(which $command)" != "" ] && [ "$HOME/Applications/$application_name/bin/$command" ]
			then
				command_location="$(which $command)"
			fi
			sudo mv "/Applications/$application_name" "$HOME/Applications"
			success "$application_name moved to $HOME/Applications."
			if [ "$command_location" != "" ]
			then
				sudo ln -sf "$HOME/Applications/$application_name/bin/$command" "$command_location"
			fi
		elif [ -d "$HOME/Applications/$application_name" ] || [ -d "/Applications/$application_name" ]
		then
			success "$application_name already installed."
		fi
	fi

	if [ -d "$extraction_path" ]
	then
		rm -rf "$extraction_path"
	fi
}

find_download_link()
{
	downloads_link="$1"
	download_link_pattern="$2"

	IFS='*' read -ra str <<< "$download_link_pattern"
	for i in "${str[@]}"
	do
	    if [ "$download_link_base_front" == "" ]
	    then
	    	download_link_base_front="$i"
	    elif [ "$download_link_rear" == "" ]
	    then
	    	download_link_rear="$i"
	    fi
	done

	if [ 1 ] #"$SILENT" == "yes" ]
	then
		silent_flag="--silent"
	fi

	# Find download link
	find_download_link_html=$(curl --location $silent_flag --url "$downloads_link")
	find_download_link_html="${find_download_link_html//href=\"/ }"
	find_download_link_html="${find_download_link_html//$download_link_rear/$download_link_rear }"
	for s in $find_download_link_html
	do
		if [ "${s%$download_link_rear}" != "$s" ]
		then
			file_name="$(basename $s)"
			latest_version="${file_name/${download_link_base_front}_/}"
			latest_version="${latest_version/${download_link_base_front}-/}"
			latest_version="${latest_version/${download_link_base_front}/}"
			latest_version="${latest_version/_${download_link_rear}/}"
			latest_version="${latest_version/-${download_link_rear}/}"
			latest_version="${latest_version/${download_link_rear}/}"
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
remove_sub_dir ()
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
