# lightsail-django

This is project is for automate django app deployment to AWS lightsail, debian instance.

Tested on Debian12 instance at aws-lightsail

## What

* Configure domain/subdomain and letsencript ssl

* Setup Django server following [this guide](https://michal.karzynski.pl/blog/2013/10/29/serving-multiple-django-applications-with-nginx-gunicorn-supervisor/)

## Run

* run `setup.sh` for the first time
* run `create-domain.sh` to create domains
* run `your-domain/new-subdomain.sh` to create sub-domains

