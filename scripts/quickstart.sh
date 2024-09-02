#!/usr/bin/bash
sudo
git clone https://github.com/digiur/digiur-net.git
groups
getent group docker
sudo usermod -aG docker $USER
getent group docker
chmod +x ./digiur-net/scripts/install.sh
echo woot
sg docker -c ./digiur-net/scripts/install.sh