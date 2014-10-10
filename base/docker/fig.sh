#!/bin/bash
#"/scripts/utilities/download-and-install.sh" fig https://github.com/orchardup/fig/releases fig/archive/*.zip "$1"
#"/scripts/utilities/github-install.sh" orchardup/fig "$1"
#https://api.github.com/repos/orchardup/fig/releases

#!/bin/bash
echo "-- Fig start --"

if [ "$1" == "install/fig.sh" ];then
	shift
fi

version="${1:-0.5.2}"
dest="/downloads/fig-$version"
if [ ! -f "$dest" ];then
	curl --location --silent --url https://github.com/orchardup/fig/releases/download/$version/linux --output "$dest"
fi
cp "$dest" /usr/local/bin/fig
chmod +x /usr/local/bin/fig && echo "$(fig --version) installed"

echo "-- Fig end --"
