#!/bin/bash
if [[ $(dpkg-query -W -f='${Status}' skywire-bin 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
	apt update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/skycoin.list
	apt -qq --yes install skywire-bin
fi
