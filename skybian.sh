#!/usr/bin/bash
#build until the server quits segfaulting on compression
if [[ $1 == "0" ]]; then
	exit 0
fi
tar -czvf skybian-script.tar.gz script
tar -czvf skybian-static.tar.gz static
updpkgsums
makepkg
