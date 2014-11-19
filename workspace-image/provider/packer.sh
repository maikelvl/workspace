#!/bin/bash
if [ -f /workspace/base/utilities/download-and-install.sh ];then
	source /workspace/base/utilities/download-and-install.sh
else
	source /scripts/utilities/download-and-install.sh
fi

download_and_install \
	packer \
	http://dl.bintray.com/mitchellh/packer/ \
	packer_*_linux_amd64.zip \
	$1