#!/bin/bash
source /workspace/base/utilities/download-and-install.sh
download_and_install \
	packer \
	http://www.packer.io/downloads.html \
	packer*_linux_amd64.zip \
	"$1"