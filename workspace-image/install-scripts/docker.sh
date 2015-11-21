#!/bin/bash
set -ex
echo "-- Docker start --"

data=$(cat $(dirname ${BASH_SOURCE[0]})/docker-version.txt)
for line in ${data// /-};do
	if [ "${line/Client-version:-/}" != "$line" ];then
		docker_client_version="${line/Client-version:-/}"
		break
	fi
done

if [ $docker_client_version ]; then
	echo -e "Downloading Docker version $docker_client_version..."
	$(dirname ${BASH_SOURCE[0]})/get-docker.sh "$docker_client_version" -x
else
	echo -e "Downloading latest Docker: get.docker.io..."
	curl --silent --location --url get.docker.io | sh -x
fi

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

echo "-- Docker end --"