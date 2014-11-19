#!/bin/bash
echo "-- Tugboat start --"

if [ "$(which tugboat)" == "" ];then
	gem install tugboat && echo "$(tugboat --version) installed"
else
	echo "$(tugboat --version) already installed"
fi

echo "-- Tugboat end --"
