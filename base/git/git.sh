#!/bin/bash
echo "-- Git start --"

version=${1:-2.1.1}

reinstall=""
if [ "$(which git)" == "" ];then
	reinstall="yes"
else
	current_version="$(git --version)"
	if [ "${current_version:12:5}" != "$version" ];then
		reinstall="yes"
	fi
fi

if [ "$reinstall" == "yes" ];then
	mkdir -p tmp-git-src
	cd tmp-git-src
	if [ "$(which yum)" != "" ];then
		yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel
		yum install -y perl-ExtUtils-MakeMaker gcc-c++ make
	elif [ "$(which apt-get)" != "" ];then
		apt-get install -y libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev
	fi
	
	dest="/downloads/git-$version.tar.gz"
	mkdir -p $(dirname $dest)
	if [ ! -f "$dest" ];then
		curl --silent --location --url https://www.kernel.org/pub/software/scm/git/git-$version.tar.gz --output "$dest"
	fi
	tar -zxf "$dest"
	cd git-$version
	make prefix=/usr/local all
	make prefix=/usr/local install
	cd ../..
	rm -rf tmp-git-src
	echo "git $version fresh installed"
else
	echo "$(git --version) was already installed"
fi

echo "-- Git end --"
