#!/bin/bash
echo "-- Git start --"

SILENT_LEVEL=1

function find_download_link()
{
	downloads_link="$1"
	download_link_base_pattern="$2"
	
	silent_flag=""
	if [ $SILENT_LEVEL -gt 1 ]
	then
		silent_flag="--silent"
	fi
	
	#curl --location $silent_flag --url $downloads_link
	links="$(curl --location $silent_flag --url $downloads_link | awk -v RS='<a' "/ href=\".*?$download_link_base_pattern\"/{ print \$1 }" | sort)"
	
	for link in $links;do
		last_item="$link"
	done

	link=$(echo $last_item | awk -F='href="' -v RS=">" '/href=".*"/{ print $1 }' | sed -e 's/href="//' | sed -e 's/"//')
	
	if [ "$link" == "" ];then
		return
	fi

	if [ "${link/\/\//}" == "$link" ];then
		link="$downloads_link$link"
	fi
	
	echo $link
}

version=$1
if [ $version ];then
	version="$version."
fi

url="$(find_download_link \
	"https://www.kernel.org/pub/software/scm/git/" \
	"git-${version//./\\.}([0-9]\.)*tar\.gz")"

if [ "$url" == "" ];then
	echo "no matching git version found"
	exit
fi

file_name="$(basename $url)"
version="${file_name/git-/}"
version="${version/.tar.gz/}"

mkdir -p tmp-git-src
cd tmp-git-src
if [ "$(which yum)" != "" ];then
	yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel
	yum install -y perl-ExtUtils-MakeMaker gcc-c++ make
elif [ "$(which apt-get)" != "" ];then
	apt-get install -y libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev
fi

dest="/downloads/$file_name"
mkdir -p $(dirname $dest)
if [ ! -f "$dest" ];then
	curl --silent --location --url "$url" --output "$dest"
fi
tar -zxf "$dest"
cd git-$version
make prefix=/usr/local all
make prefix=/usr/local install
cd ../..
rm -rf tmp-git-src

if [ $(which git) ]
then
	echo "Git $version fresh installed"
else
	echo "Installing Git failed"
fi

echo "-- Git end --"
