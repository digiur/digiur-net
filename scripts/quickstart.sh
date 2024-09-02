#!/usr/bin/bash
sudo groupadd docker
groups
getent group docker
sudo usermod -aG docker $USER
getent group docker
git clone https://github.com/digiur/digiur-net.git
chmod +x ./digiur-net/scripts/install.sh
sg docker -c ./digiur-net/scripts/install.sh