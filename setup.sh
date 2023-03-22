#!/usr/bin/env bash

#################################################
# Setup debian-9 to serve django project
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

# Get lightsail-django current directory.
LIGHTSAIL_DJANGO=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

clear
echo "#################################################"
echo "# Setup Server"

# Make commands invokes serially, exit on error
set -euo pipefail

# Install dependencies
$LIGHTSAIL_DJANGO/scripts/install-dependencies.sh

# create webapps directory
sudo mkdir -p /webapps

# create webapps group
sudo groupadd --system webapps

# Create swap
$LIGHTSAIL_DJANGO/scripts/create-swap.sh
