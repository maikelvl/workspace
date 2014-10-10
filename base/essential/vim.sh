#!/bin/bash
echo "-- VIM start --"

if [ "$(which vim)" == "" ];then
	if [ "$(which yum)" != "" ];then
		yum install -y vim
	elif [ "$(which apt-get)" != "" ];then
		DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install vim
	fi
else
	echo "VIM $(vim --version) was already installed"
fi

echo "-- VIM end --"

