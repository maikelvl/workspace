#!/bin/bash
if [ -f /workspace/base/utilities/download-and-install.sh ];then
	source /workspace/base/utilities/download-and-install.sh
else
	source /scripts/utilities/download-and-install.sh
fi

download_and_install \
	terraform \
	http://dl.bintray.com/mitchellh/terraform/ \
	terraform_*_linux_amd64.zip \
	$1