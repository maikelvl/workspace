#!/bin/bash
if [ -f /workspace/base/utilities/download-and-install.sh ];then
	source /workspace/base/utilities/download-and-install.sh
else
	source /scripts/utilities/download-and-install.sh
fi

download_and_install \
	node \
	http://nodejs.org/download/ \
	node-v*-linux-x64.tar.gz \
	$1
