#!/bin/bash
echo "-- Dot start --"

if [ "$(which dot)" == "" ];then
	if [ "$(which yum)" != "" ];then
		yum install -y graphviz
	elif [ "$(which apt-get)" != "" ];then
		DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y graphviz
	fi
else
	echo "$(dot --version) was already installed"
fi
echo "-- Dot end --"