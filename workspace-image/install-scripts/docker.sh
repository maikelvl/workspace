#!/bin/ash
set -ex
docker_client_version="latest"
data=$(cat $(dirname $0)/docker-version.txt)
for line in ${data// /-};do
	if [ "${line/Client-version:-/}" != "$line" ];then
		docker_client_version="${line/Client-version:-/}"
		break
	fi
done

echo -e "Downloading Docker version $docker_client_version..."
curl -L https://get.docker.com/builds/Linux/x86_64/docker-$docker_client_version -o /usr/bin/docker && \
chmod +x /usr/bin/docker
