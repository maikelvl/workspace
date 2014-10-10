#!/bin/bash
echo "-- Docker start --"

if [ "$(which docker)" == "" ];then
	echo -e "Downloading latest Docker: get.docker.io..."
	curl --silent --location --url get.docker.io | sh -x
	
	if id -u root >/dev/null 2>&1; then
		gpasswd -a root docker
	fi

	if [ "$(which docker)" != "" ];then
		echo "Docker installed: $(docker --version)"
		docker rm -f $(docker ps -aq) # remove all existing containers
		docker rmi -f $(docker images -q) # remove all existing images
	else
		echo "Something went wrong installing Docker"
	fi
else
	echo "Docker $(docker --version) was already installed. Updating:"
	apt-get install lxc-docker
fi

echo "-- Docker end --"