#!/bin/ash
set -ex

echo -e "Downloading latest Composer..."
curl --location --silent --url https://getcomposer.org/installer | php
mv ./composer.phar /usr/bin/composer
chmod +x /usr/bin/composer
if [ "$(which composer)" == "" ];then
    printf "\e[0;31m"
    echo "Something went wrong installing composer"
    printf "\e[0m"
    exit 1
else
	echo "$(composer --version) installed"
fi
