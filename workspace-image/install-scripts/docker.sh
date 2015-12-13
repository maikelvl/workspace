#!/bin/ash
set -e
docker_client_version="$(cat /DOCKER_VERSION)"
echo -e "Downloading Docker version $docker_client_version..."
curl -L https://get.docker.com/builds/Linux/x86_64/docker-$docker_client_version -o /usr/bin/docker && \
chmod +x /usr/bin/docker
