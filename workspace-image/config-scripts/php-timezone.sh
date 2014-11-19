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

function error ()
{
    printf "$red"
    echo "$1"
    printf "$NC"
}

if [ "$TIMEZONE" != "" ]
then
	# if [ "$LOG_LEVEL" != "0" ]
	# then
	# 	info    "Time zone:       $TIMEZONE"
	# 	echo -e "Local time:      $(date)"
	# 	echo -e "Universal time:  $(date -u)"
	# fi

	if [ -f /etc/php5/fpm/php.ini ]
	then
		sed -i "s/;date.timezone =/date.timezone =/" /etc/php5/fpm/php.ini
		sed -i "s/date.timezone =.*/date.timezone = ${TIMEZONE//\//\\\/}/" /etc/php5/fpm/php.ini
	fi

	if [ -f /etc/php5/cli/php.ini ]
	then
		sed -i "s/;date.timezone =/date.timezone =/" /etc/php5/cli/php.ini
		sed -i "s/date.timezone =.*/date.timezone = ${TIMEZONE//\//\\\/}/" /etc/php5/cli/php.ini
	fi
else
	error "Missing argument: TIMEZONE"
fi

