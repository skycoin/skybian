#!/usr/bin/bash
#build until the server quits segfaulting on compression
tar -czvf skybian-script.tar.gz script
tar -czvf skybian-static.tar.gz static
tar -czvf skybian-util.tar.gz util
updpkgsums
makepkg
