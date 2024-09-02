#!/usr/bin/bash
groups
sudo groupadd docker
groups
getent group docker
sudo usermod -aG docker $USER
getent group docker
groups
chmod +x ./digiur-net/scripts/install.sh
sg docker -c ./digiur-net/scripts/install.sh