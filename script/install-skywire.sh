#!/bin/bash
	apt update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/skycoin.list &&	apt -qq --yes reinstall skywire-bin && systemctl is-active --quiet install-skywire && systemctl disable install-skywire 2> /dev/null
