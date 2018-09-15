#!/bin/bash -v
set -ex

if [ -b /dev/xvdh ]
then
    sudo mkdir /data
    sudo mkfs.xfs /dev/xvdh
    sudo mount /dev/xvdh /data
fi
sudo mkdir -p /data/{db,log}

sudo echo "`curl http://169.254.169.254/latest/meta-data/local-ipv4` mongodb${node_number}.${region}.${domain}" >> /etc/hosts
sudo setenforce 0
