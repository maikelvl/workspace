#!/bin/bash

red="\e[0;31m"
NC="\e[0m"

echo "-- Composer start --"

echo -e "Downloading latest Composer..."
curl --location --silent --url https://getcomposer.org/installer | php
mv ./composer.phar /usr/local/bin/composer
chmod a+x /usr/local/bin/composer
if [ "$(which composer)" == "" ];then
	printf "$red"
	echo "Something went wrong installing composer"
	printf "$NC"
else
	echo "$(composer --version) installed"
fi

echo "-- Composer end --"
