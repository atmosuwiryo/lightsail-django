#!/usr/bin/env bash

#################################################
# Setup debian-12 to serve nodejs project
# For debian-12 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################


#################################################
# Functions Start Here
add_to_crontab() {
    echo '> Add Certbot Renew to Crontab'
    TMP_FILE=$(mktemp)
    sudo crontab -l | tee $TMP_FILE > /dev/null
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | tee -a $TMP_FILE > /dev/null
    sudo crontab $TMP_FILE
    rm $TMP_FILE
}
# Functions End Here


# Get lightsail-nodejs current directory.
LIGHTSAIL_NODEJS=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

clear
echo "#################################################"
echo "# Add New Domain"

# Color Variable
Gre='\033[0;32m';  # Green
NoC='\033[0m';  # No Color

# Make commands invokes serially
set -euo pipefail

#################################################
# Get domain and email data
if [ -z ${2+x} ]; then
    echo -e -n "${Gre}"
    read -p "Your domain name: " DOMAIN
    read -p "Email for generating ssl: " EMAIL
    echo -e -n "${NoC}"
else
    DOMAIN=$1
    EMAIL=$2
fi
SANITIZED_DOMAIN=${DOMAIN//./_} 

#################################################
# Creating domain conf file
CONF="$LIGHTSAIL_NODEJS/$DOMAIN/domain.conf.json"
EXAMPLE_CONF="$LIGHTSAIL_NODEJS/template/domain.conf.json"
TMP_CONF=$(mktemp)

mkdir -p $DOMAIN
if [ ! -e $CONF ]; then
    echo "Conf file not exist, creating $CONF"
    jq '.subDomains=[]' $EXAMPLE_CONF > $CONF 
fi

# Updating conf domain name
jq --arg domainName $DOMAIN --arg email $EMAIL \
    '.domainName = $domainName | .sslEmail = $email' $CONF \
    > $TMP_CONF && mv $TMP_CONF $CONF

echo -e -n "${Gre}"
echo "Configuration saved to $CONF"
echo -e -n "${NoC}"

# Add new subdomain scripts link file to domain directory
ln -s $LIGHTSAIL_NODEJS/scripts/new-subdomain.sh $LIGHTSAIL_NODEJS/$DOMAIN/new-subdomain.sh

#################################################
# Add new user
echo '> Creating User'
sudo useradd --system --gid webapps --shell /bin/bash --home /webapps/${SANITIZED_DOMAIN}__nodejs $SANITIZED_DOMAIN

# Create user directory
echo '> Creating User Directory'
sudo mkdir -p /webapps/${SANITIZED_DOMAIN}__nodejs/
sudo chown $SANITIZED_DOMAIN /webapps/${SANITIZED_DOMAIN}__nodejs/

#################################################
# Create nodejs project
echo '> Creating Node Js Project template'
sudo su - $SANITIZED_DOMAIN -c 'cd ~ && 
    mkdir -p dist &&
    cp "$PWD/template/main.js" "dist/main.js"'

#################################################
# Setup to serve nodejs project
# Copy supervisor conf script
echo '> Creating Supervisor Conf Script'
sudo su - $SANITIZED_DOMAIN -c ' mkdir /webapps/${0}__nodejs/logs && 
    touch /webapps/${0}__nodejs/logs/gunicorn_supervisor.log' -- $SANITIZED_DOMAIN
sudo sed "s/CHANGE_HERE/$SANITIZED_DOMAIN/g" "$PWD/template/supervisor_node.conf" | sudo tee "/etc/supervisor/conf.d/${SANITIZED_DOMAIN}.conf" > /dev/null

# Reread & update supervisor to start apps
sudo supervisorctl reread
sudo supervisorctl update

#################################################
# Setup web server
# Copy nginx entry
echo '> Creating Nginx Entry'
sudo sed "s/CHANGE_HERE/$SANITIZED_DOMAIN/g; s/DOMAIN_HERE/$DOMAIN/g" "$PWD/template/nginx_entry_node" | sudo tee "/etc/nginx/sites-available/$DOMAIN" > /dev/null

# Enable nginx entry
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

# Add let's encrypt https
echo '> Creating Lets Encrypt certificate'
sudo certbot --nginx -m $EMAIL --preferred-challenges http-01 --agree-tos --redirect -d $DOMAIN -d www.$DOMAIN 
# Add to cronjob if not exists
sudo crontab -l | grep -q "certbot renew" || add_to_crontab

# Restart nginx
echo '> Restarting nginx'
sudo service nginx restart
