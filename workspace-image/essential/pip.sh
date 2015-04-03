#!/bin/bash
echo "-- PIP start --"

curl -L https://bootstrap.pypa.io/get-pip.py | python
apt-get install -y python-yaml python-dev libxml2-dev libxslt-dev

echo "-- PIP end --"

