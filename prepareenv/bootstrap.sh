#!/bin/bash
set -xe 

# Install and enable docker
sudo yum install docker -y

sudo systemctl enable docker
sudo systemctl start docker

# Added centos user to docker group
sudo chown root:dockerroot /var/run/docker.sock
sudo usermod -aG dockerroot centos

# Install docker compose and build and run containers
cd /tmp/prepareenv
if [ -f /bin/docker-compose ]
then
    sudo /bin/docker-compose build
    sudo /bin/docker-compose up -d
else
    sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose
    sudo chmod +x ./docker-compose
    sudo ./docker-compose build
    sudo ./docker-compose up -d
fi

