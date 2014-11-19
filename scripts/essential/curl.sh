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

if [ ! -f "/usr/local/opt/curl-ca-bundle/share/ca-bundle.crt" ];then
	apt-get install -y ca-certificates
	mkdir -p /usr/local/opt/curl-ca-bundle/share
	cp /etc/ssl/certs/ca-certificates.crt /usr/local/opt/curl-ca-bundle/share/ca-bundle.crt
fi

echo "-- Curl end --"