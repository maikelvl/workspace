#!/bin/bash
source /scripts/utilities/download-and-install.sh
download_and_install \
	terraform \
	http://www.terraform.io/downloads.html \
	terraform_*_linux_amd64.zip \
	"$1"