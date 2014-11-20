#!/bin/bash
echo "-- Curl start --"

if [ "$(which curl)" == "" ];then
	if [ "$(which yum)" != "" ];then
		yum install -y curl
	elif [ "$(which apt-get)" != "" ];then
		DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y curl
	fi
else
	curl_version="$(curl --version)"
	echo "${curl_version:0:12} was already installed"
	echo "${curl_version:12}"
fi

echo "-- Curl end --"