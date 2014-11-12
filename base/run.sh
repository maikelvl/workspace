#!/bin/sh

for file in $(ls /etc/my_init.d)
do
	/etc/my_init.d/$file
done

[ -d "/usr/local/node/bin" ] && export PATH="/usr/local/node/bin:$PATH"

bash
