#!/bin/bash
export BLACK="\e[0;30m"
export RED="\e[0;31m"
export GREEN="\e[0;32m"
export ORANGE="\e[0;33m"
export BLUE="\e[0;34m"
export PURPLE="\e[0;35m"
export TURQUASE="\e[0;36m"
export NC="\e[0m"

function info()
{
    printf "$BLUE"
    echo -e "$@"
    printf "$NC"
}

function success()
{
    printf "$GREEN"
    echo -e "$@"
    printf "$NC"
}

function error()
{
    printf "$RED"
    echo -e "$@"
    printf "$NC"
}

if [ $LOG ];then
	echo "-- Timezone start --"
fi

timezone_file="/etc/timezone"

timezone="$1"
if [ $timezone ];then
	if [ -f $timezone_file.bak ];then
		cp -f $timezone_file.bak $timezone_file
	elif [ -f $timezone_file ];then
		cp -f $timezone_file $timezone_file.bak
	else
		echo "$timezone" > $timezone_file
	fi
	
	if [ "$(cat $timezone_file)" != "$timezone" ];then
		echo "$timezone" > $timezone_file
		dpkg-reconfigure --frontend noninteractive tzdata &>-
		rm ./-
	fi
	if [ $LOG ];then
		info "Time zone:       $timezone"
		echo -e "Local time:      $(date)"
		echo -e "Universal time:  $(date -u)"
	fi
	if [ -f /etc/php5/fpm/php.ini ];then
		sed -i "s/;date.timezone =/date.timezone =/" /etc/php5/fpm/php.ini
		sed -i "s/date.timezone =.*/date.timezone = ${timezone//\//\\\/}/" /etc/php5/fpm/php.ini
	fi

	if [ -f /etc/php5/cli/php.ini ];then
		sed -i "s/;date.timezone =/date.timezone =/" /etc/php5/cli/php.ini
		sed -i "s/date.timezone =.*/date.timezone = ${timezone//\//\\\/}/" /etc/php5/cli/php.ini
	fi
else
	error "Missing argument: timezone"
fi
if [ $LOG ];then
	echo "-- Timezone end --"
fi
