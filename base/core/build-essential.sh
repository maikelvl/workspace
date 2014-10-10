#!/bin/bash
echo "-- Build essential start --"

if [ "$(which yum)" != "" ];then
	yum install -y yum-utils make automake gcc gcc-c++ kernel-devel
elif [ "$(which apt-get)" != "" ];then
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		build-essential \
		software-properties-common \
		python-software-properties \
		gcc \
		make \
		autoconf \
		yodl \
		libncursesw5-dev \
		texinfo \
		checkinstall
fi

echo "-- Build essential end --"