#!/usr/bin/env bash

#################################################
# Setup debian-9 to serve django project
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

clear
echo "#################################################"
echo "# Add New Domain"

# Color Variable
Gre='\033[0;32m';  # Green
NoC='\033[0m';  # No Color

# Make commands invokes serially
sudo set -euo pipefail

#################################################
# Get domain and email data
if [ -z ${2+x} ]; then
    echo -e -n "${Gre}"
    read -p "Your domain name: " DOMAIN
    read -p "Email for generating ssl: " EMAIL
    echo -e -n "${NoC}"
else
    DOMAIN=$1
    USER=$DOMAIN
    EMAIL=$2
fi

#################################################
# Creating domain conf file
CONF="$DOMAIN/ocmsta.conf.json"
EXAMPLE_CONF="template/domain.conf.json"
TMP_CONF=$(mktemp)
if [ ! -e $CONF ]; then
    echo "Conf file not exist, creating $CONF"
    jq '.subDomains=[]' $EXAMPLE_CONF > $CONF 
fi

# Updating domain name
jq --arg domainName $DOMAIN --arg email $EMAIL \
'.domainName = $domainName | .sslEmail = $email' $CONF \
> $TMP_CONF && mv $TMP_CONF $CONF

echo -e -n "${Gre}"
echo "Configuration saved to $CONF"
echo -e -n "${NoC}"


#################################################
# Add new user
sudo useradd --system --gid webapps --shell /bin/bash --home /webapps/$USER_django $USER

# Create user directory
sudo mkdir -p /webapps/$USER_django/
sudo chown $USER /webapps/$USER_django/

#################################################
# Create django project
sudo su - $USER -c 'cd ~ && 
virtualenv . && 
source bin/activate && 
pip install django gunicorn setproctitle && 
django-admin.py startproject $0 && 
deactivate' -- $USER

# Copy gunicorn start script
sudo su - $USER -c '
sed "s/CHANGE_HERE/$1/g" "$0/gunicorn_start" > "/webapps/$1_django/bin/gunicorn_start"
' -- $PWD/template $USER

# Copy supervisor conf script
sudo su -c '
sed "s/CHANGE_HERE/$1/g" "$0/supervisor.conf" > "/etc/supervisor/conf.d/$1.conf"
' -- $PWD/template $USER

# Reread & update supervisor to start apps
sudo supervisorctl reread
sudo supervisorctl update

# Copy nginx entry
sudo su -c 'sed "s/CHANGE_HERE/$1/g" "$0/nginx_entry" > "/etc/nginx/sites-available/$1"' -- $PWD/template $USER

# Enable nginx entry
sudo ln -s /etc/nginx/sites-available/$USER /etc/nginx/sites-enabled/$USER

# Add let's encrypt https
sudo certbot --nginx -m $EMAIL --agree-tos --redirect --quiet -d $DOMAIN -d www.$DOMAIN 

# Restart nginx
sudo service nginx restart