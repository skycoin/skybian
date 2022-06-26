#!/usr/bin/bash
#build until the server quits segfaulting on compression
tar -czvf skybian-script.tar.gz script
tar -czvf skybian-static.tar.gz static
updpkgsums
makepkg
