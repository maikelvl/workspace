#!/bin/bash
echo "-- PIP start --"

curl \
	--location \
	--url https://bootstrap.pypa.io/get-pip.py | python

apt-get install -y \
	python-yaml \
	python-dev \
	libxml2-dev \
	libxslt-dev
	
pip install --upgrade pip

echo "-- PIP end --"

