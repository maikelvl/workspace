#!/bin/bash
echo "-- Linux-image-extra start --"

if [ "$(which yum)" != "" ];then
	#yum install -y linux-image-extra-`uname -r`
	yum install -y epel-release
elif [ "$(which apt-get)" != "" ];then
	apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y linux-image-extra-`uname -r`
fi

echo "-- Linux-image-extra end --"