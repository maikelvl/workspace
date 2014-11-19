#!/bin/bash

# 	dist-upgrade
#        dist-upgrade in addition to performing the function of upgrade,
#        also intelligently handles changing dependencies with new versions
#        of packages; apt-get has a "smart" conflict resolution system, and
#        it will attempt to upgrade the most important packages at the
#        expense of less important ones if necessary. So, dist-upgrade
#        command may remove some packages. The /etc/apt/sources.list file
#        contains a list of locations from which to retrieve desired package
#        files. See also apt_preferences(5) for a mechanism for overriding
#        the general settings for individual packages.
#

# yum update === apt-get upgrade

echo "-- Dist Upgrade start --"

if [ "$(which yum)" != "" ];then
	yum upgrade -y
elif [ "$(which apt-get)" != "" ];then
	DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
fi

echo "-- Dist Upgrade end --"