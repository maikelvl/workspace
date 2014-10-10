#!/bin/bash
echo "-- Tree start --"

if [ "$(which tree)" == "" ];then
	if [ "$(which yum)" != "" ];then
		yum install -y tree
	elif [ "$(which apt-get)" != "" ];then
		DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install tree
	fi
else
	echo "$(tree --version) was already installed"
fi

echo "-- Tree end --"

