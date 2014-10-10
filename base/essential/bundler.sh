#!/bin/bash
echo "-- Bundler start --"

if [ "$(which bundle)" == "" ];then
	if [ "$(which yum)" != "" ];then
		yum install -y ruby-bundler
	elif [ "$(which apt-get)" != "" ];then
		DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y ruby-bundler
	fi
else
	echo "Bundler $(bundle --version) was already installed"
fi

echo "-- Bundler end --"