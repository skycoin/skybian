#!/bin/bash
	apt update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/skycoin.list &&	apt -qq --yes reinstall skywire-bin
