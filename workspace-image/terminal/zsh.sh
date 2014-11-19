#!/bin/bash
echo "-- ZSH start --"

BRANCH="$1"

# Build Zsh from sources on Ubuntu.
# From http://zsh.sourceforge.net/Arc/git.html and sources INSTALL file.
 
# Make script gives up on any error
set -e
 
# Some packages may be missing

 
# Clone zsh repo and change to it

dest="/downloads/zsh"
if [ ! -d "$dest" ];then
	git clone git://git.code.sf.net/p/zsh/code "$dest"
fi
cp -r "$dest" zsh
cd zsh

# Get lastest stable version, but you can change to any valid branch/tag/commit id
if [ "$BRANCH" == "" ];then
	BRANCH=$(git describe --abbrev=0 --tags)
fi

# Get version number, and revision/commit id when this is available
ZSH_VERSION=$(echo $BRANCH | cut -d '-' -f2,3,4)
# Go to desired branch
git checkout $BRANCH
 
# Make configure
./Util/preconfig
 
# Options from Ubuntu Zsh package rules file (http://launchpad.net/ubuntu/+source/zsh)
# Updated to zsh 5.0.2 on Trusty Tahr (pre-release)
./configure --prefix=/usr \
            --mandir=/usr/share/man \
            --bindir=/bin \
            --infodir=/usr/share/info \
            --enable-maildir-support \
            --enable-max-jobtable-size=256 \
            --enable-etcdir=/etc/zsh \
            --enable-function-subdirs \
            --enable-site-fndir=/usr/local/share/zsh/site-functions \
            --enable-fndir=/usr/share/zsh/functions \
            --with-tcsetpgrp \
            --with-term-lib="ncursesw tinfo" \
            --enable-cap \
            --enable-pcre \
            --enable-readnullcmd=pager \
            --enable-custom-patchlevel=Debian \
            --enable-additional-fpath=/usr/share/zsh/vendor-functions,/usr/share/zsh/vendor-completions \
            LDFLAGS="-Wl,--as-needed -g -Wl,-Bsymbolic-functions -Wl,-z,relro"
 
# Compile, test and install
make -j5
make check
checkinstall -y --pkgname=zsh --pkgversion=$ZSH_VERSION --pkglicense=MIT make install install.info 
 
# Make zsh the default shell
sudo sh -c "echo /bin/zsh >> /etc/shells"

# home="/home/vagrant"
# url="http://sourceforge.net/projects/zsh/files"
# if [ "$version" == "" ];then
# 	url="$url/latest/download?source=files"
# else
# 	url="$url/zsh/$version/zsh-$version.tar.bz2/download"
# fi

# echo "Downloading zsh ${version:=latest}..."
# curl --location --silent --output $home/zsh.tar.bz2 --url $url
# mkdir $home/tmp-zsh
# tar xfv $home/zsh.tar.bz2 --bzip2 --directory=$home/tmp-zsh --strip-components=1
# cd $home/tmp-zsh
# ./configure --with-tcsetpgrp --with-term-lib="ncursesw tinfo"
# make all
# make install
# cd ..

# if [ -f $home/zsh.tar.bz2 ];then
# 	rm $home/zsh.tar.bz2
# fi
# # if [ -d $home/tmp-zsh ];then
# # 	rm -rf $home/tmp-zsh
# # fi
cd ..
if [ -d "zsh" ];then
	rm -rf zsh
fi

if [ "$(which zsh)" != "" ];then
	echo "ZSH installed: $(zsh --version)"
else
	echo "Something went wrong installing ZSH"
fi

if [ ! -f $HOME/.zshrc ];then
	echo "" > $HOME/.zshrc
fi

echo "-- ZSH end --"

