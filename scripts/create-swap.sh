#!/usr/bin/env bash

#################################################
# Creating swap file
# For debian-9 instance at aws-lightsail
# suwiryo.atmo@gmail.com - 27/May/2020
#################################################

clear
echo "#################################################"
echo "# Creating Swap"

# Make commands invokes serially, exit on error
set -euo pipefail

TARGET_SWAP_SIZE=$(grep MemTotal /proc/meminfo | awk '{if ($2 < 4194304) print int($2*4/1024); else print 2^14}')
SWAP_SIZE=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
if ((${SWAP_SIZE} == 0)); then
    echo 'Creating swap'
    sudo fallocate -l ${TARGET_SWAP_SIZE}M /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null 
    sudo sysctl vm.swappiness=20
    grep -q "vm.swappiness=20" /etc/sysctl.conf | echo "vm.swappiness=20" | sudo tee -a /etc/sysctl.conf > /dev/null
else
    echo 'Not Creating swap'
fi
sudo swapon --show
