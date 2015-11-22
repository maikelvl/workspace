#!/bin/ash
set -e

version=$(git --version | sed -rn "s/.*(\d+\.\d+\.\d+).*/\1/p")
curl \
    --location \
    --url https://github.com/git/git/archive/v${version}.zip \
    --output /tmp/git.zip

unzip -d /tmp/git /tmp/git.zip
rm /tmp/git.zip
perl_path="/usr/share/perl5/site_perl"
mkdir -p $perl_path
mv /tmp/git/$(ls /tmp/git)/perl/* $perl_path/
rm -rf /tmp/git
rm $perl_path/Makefile*
cp $perl_path/private-Error.pm $perl_path/Error.pm
