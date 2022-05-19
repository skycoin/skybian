#!/bin/bash
#script to install latest binary release of skywire from repository configured with apt
apt -qq update
apt -qq --yes --force-yes install skywire-bin
systemctl disable --now install-skywire
