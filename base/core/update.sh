#!/bin/bash

# yum update === apt-get upgrade

echo "-- Update start --"

if [ "$(which yum)" != "" ];then
	echo "RHEL don't need to update"
elif [ "$(which apt-get)" != "" ];then
	DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update
fi

echo "-- Update end --"