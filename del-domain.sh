#!/usr/bin/env bash

#################################################
# Setup debian-9 to serve django project
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

clear
echo "#################################################"
echo "# Removing Domain"

# Color Variable
Gre='\033[0;32m';  # Green
NoC='\033[0m';  # No Color

# Make commands invokes serially
set -euo pipefail

#################################################
# Get domain data
if [ -z ${1+x} ]; then
    echo -e -n "${Gre}"
    read -p "Domain to remove: " DOMAIN
    echo -e -n "${NoC}"
else
    DOMAIN=$1
fi
SANITIZED_DOMAIN=${DOMAIN/./_} 

#################################################
# Cleanup supervisor

# Removing supervisor conf script
echo '> Removing Supervisor Conf Script'
sudo supervisorctl stop $SANITIZED_DOMAIN
sudo rm /etc/supervisor/conf.d/${SANITIZED_DOMAIN}.conf

# Reread & update supervisor to remove apps
sudo supervisorctl reread
sudo supervisorctl update

#################################################
# Deleting user
echo '> Deleting User'
sudo userdel $SANITIZED_DOMAIN
sudo rm -rf /webapps/${SANITIZED_DOMAIN}__django

#################################################
# Cleanup web server
echo '> Removing Nginx Entry'

# Removing nginx entry
sudo rm -rf /etc/nginx/sites-enabled/$DOMAIN
sudo rm -rf /etc/nginx/sites-available/$DOMAIN

#################################################
# Deleting domain conf direktori
echo '> Deleting Domain Direktori'
rm -rf $DOMAIN

# Restart nginx
echo '> Restarting nginx'
sudo service nginx restart