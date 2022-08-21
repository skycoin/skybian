#!/usr/bin/bash
## BUILD FOR SKYBIAN.deb PACKGE
#build until the server quits segfaulting on compression
if [[ $1 == "0" ]]; then
	exit 0
fi
tar -czvf skybian-script.tar.gz script
tar -czvf skybian-static.tar.gz static
updpkgsums
set -e
makepkg
set +e
if [[ $1 == "wait" ]]; then
read -s -n 1 -p "Press any key to continue . . ."
echo ""
fi
