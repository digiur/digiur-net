#!/usr/bin/bash
git clone https://github.com/digiur/digiur-net.git
groups
getent group docker
sudo usermod -aG docker $USER
getent group docker
echo -n "Ready to install. Press any key to continue..."
read -n 1 -s
sg docker -c ./digiur-net/scripts/install.sh