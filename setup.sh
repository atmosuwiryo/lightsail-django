#!/usr/bin/env bash

#################################################
# Setup debian-9 to serve django project
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

clear
echo "#################################################"
echo "# Setup Server"

# Make commands invokes serially
sudo set -euo pipefail

# Install dependencies
./scripts/install-dependencies.sh

# create webapps directory
sudo mkdir /webapps

# create webapps group
sudo groupadd --system webapps