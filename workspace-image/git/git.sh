#!/bin/bash
echo "-- Git start --"

add-apt-repository ppa:git-core/ppa -y
apt-get update
apt-get install -y git
git --version

echo "-- Git end --"
