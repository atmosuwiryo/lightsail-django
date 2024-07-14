#!/usr/bin/env bash

#################################################
# Setup debian-9 to serve django project
# For debian-9 instance at aws-lightsail
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


# Get lightsail-django current directory.
LIGHTSAIL_DJANGO=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

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
CONF="$LIGHTSAIL_DJANGO/$DOMAIN/domain.conf.json"
EXAMPLE_CONF="$LIGHTSAIL_DJANGO/template/domain.conf.json"
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
ln -s $LIGHTSAIL_DJANGO/scripts/new-subdomain.sh $LIGHTSAIL_DJANGO/$DOMAIN/new-subdomain.sh

#################################################
# Add new user
echo '> Creating User'
sudo useradd --system --gid webapps --shell /bin/bash --home /webapps/${SANITIZED_DOMAIN}__django $SANITIZED_DOMAIN

# Create user directory
echo '> Creating User Directory'
sudo mkdir -p /webapps/${SANITIZED_DOMAIN}__django/
sudo chown $SANITIZED_DOMAIN /webapps/${SANITIZED_DOMAIN}__django/

#################################################
# Create django project
echo '> Creating Django Project'
sudo su - $SANITIZED_DOMAIN -c 'cd ~ && 
    virtualenv -p python3 . && 
    source bin/activate && 
    pip install django gunicorn setproctitle && 
    django-admin startproject $0 && 
    deactivate' -- $SANITIZED_DOMAIN

# Add domain to Allowed host in settings.py
sudo su - $SANITIZED_DOMAIN -c '
    sed -i "s~ALLOWED_HO.*~ALLOWED_HOSTS = [\"${1}\"]~" ${0}/${0}/settings.py
    ' -- $SANITIZED_DOMAIN $DOMAIN

# Do migration
sudo su - $SANITIZED_DOMAIN -c '
    source bin/activate && 
    python ${0}/manage.py migrate
    ' -- $SANITIZED_DOMAIN

#################################################
# Setup to serve django project
# Copy gunicorn start script
echo '> Creating Gunicorn Start Script'
sudo su - $SANITIZED_DOMAIN -c '
    sed "s/CHANGE_HERE/$1/g" "$0/gunicorn_start" > "/webapps/$1__django/bin/gunicorn_start"
    ' -- $PWD/template $SANITIZED_DOMAIN
sudo chmod u+x /webapps/${SANITIZED_DOMAIN}__django/bin/gunicorn_start

# Copy supervisor conf script
echo '> Creating Supervisor Conf Script'
sudo su - $SANITIZED_DOMAIN -c ' mkdir /webapps/${0}__django/logs && 
    touch /webapps/${0}__django/logs/gunicorn_supervisor.log' -- $SANITIZED_DOMAIN
sudo sed "s/CHANGE_HERE/$SANITIZED_DOMAIN/g" "$PWD/template/supervisor.conf" | sudo tee "/etc/supervisor/conf.d/${SANITIZED_DOMAIN}.conf" > /dev/null

# Reread & update supervisor to start apps
sudo supervisorctl reread
sudo supervisorctl update

#################################################
# Setup web server
# Copy nginx entry
echo '> Creating Nginx Entry'
# sudo su -c 'sed "s/CHANGE_HERE/$1/g; s/DOMAIN_HERE/$2/g" "$0/nginx_entry" > "/etc/nginx/sites-available/$1"' -- $PWD/template $SANITIZED_DOMAIN $DOMAIN
sudo sed "s/CHANGE_HERE/$SANITIZED_DOMAIN/g; s/DOMAIN_HERE/$DOMAIN/g" "$PWD/template/nginx_entry" | sudo tee "/etc/nginx/sites-available/$DOMAIN" > /dev/null

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
