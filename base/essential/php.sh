#!/bin/bash
echo "-- PHP start --"

#sudo apt-get --purge remove -y php5-common

if [ "$(which yum)" != "" ];then
	yum install -y php
elif [ "$(which apt-get)" != "" ];then
	add-apt-repository -y ppa:ondrej/php5
	add-apt-repository -y ppa:nginx/stable
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y php5-cli php5-fpm php5-mysql php5-pgsql php5-sqlite php5-curl php5-gd php5-mcrypt php5-intl php5-imap php5-tidy
fi

php_ini="/etc/php5/cli/php.ini"
if [ -f "$php_ini.bak" ];then
	cp -f "$php_ini.bak" "$php_ini"
else
	cp -f "$php_ini" "$php_ini.bak"
fi

php5enmod mcrypt

apt-get install -y --force-yes \
	php-pear \
	php5-dev \
	php5-curl \
	php5-gd \
	php5-mcrypt \
	libpcre3-dev \
	libyaml-dev \
	libssh2-php

printf "\n" | pecl install pecl_http
printf "\n" | pecl install yaml

#echo "extension=http.so" >> /etc/php5/cli/php.ini
echo "extension=yaml.so" >> /etc/php5/cli/php.ini

echo "-- PHP end --"