#!/usr/bin/env bash

#################################################
# Install needed package to deploy django
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

echo ""
echo "#################################################"
echo "# Install Dependencies"

# Make commands invokes serially, exit on error
set -euo pipefail

sudo apt-get update -y
sudo apt-get upgrade -y

# Dependencies for serving django
sudo apt-get install -y supervisor
sudo apt-get install -y nginx
sudo apt-get install -y python3-virtualenv

# Dependencies for using postgres database
sudo apt-get install -y postgresql postgresql-contrib
sudo apt-get install -y libpq-dev python-dev-is-python3 python3-dev gcc

# Dependency to manage let's encrypt certificate
sudo apt-get install -y python3-certbot-nginx

# Dependencies for managing this scripts
sudo apt-get install -y jq

# Needed for project maintenance
sudo apt-get install git

# Needed for renew certificate automatically
sudo apt-get install cron

# Needed for NestJS
sudo apt-get install nodejs
sudo apt-get install npm
