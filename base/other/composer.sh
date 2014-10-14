#!/bin/bash

black="\e[0;30m"
red="\e[0;31m"
green="\e[0;32m"
orange="\e[0;33m"
blue="\e[0;34m"
purple="\e[0;35m"
turquase="\e[0;36m"
NC="\e[0m"

function info ()
{
    printf "$turquase"
    echo "$1"
    printf "$NC"
}

function success ()
{
    printf "$green"
    echo "$1"
    printf "$NC"
}

function warning ()
{
    printf "$orange"
    echo "$1"
    printf "$NC"
}

function error ()
{
    printf "$red"
    echo "$1"
    printf "$NC"
}

echo "-- Composer start --"

echo -e "Downloading latest Composer..."
curl --location --silent --url https://getcomposer.org/installer | php
mv ./composer.phar /usr/local/bin/composer
chmod a+x /usr/local/bin/composer
if [ "$(which composer)" == "" ];then
	errpr "Something went wrong installing composer"
else
	echo "$(composer --version) installed"
fi

echo "-- Composer end --"
