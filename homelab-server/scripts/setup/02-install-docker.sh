#!/usr/bin/env bash
###############################################################################
# One-time: install Docker Engine + Compose plugin.                        #
# See: https://docs.docker.com/engine/install/ubuntu/                      #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"
# shellcheck disable=SC1091
source /etc/os-release # for $UBUNTU_CODENAME

show 2 "Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

show 2 "Adding the Docker repository to apt sources..."
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $UBUNTU_CODENAME stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

show 2 "Installing Docker packages..."
sudo apt-get update -y
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

show 2 "Verifying Docker service is running..."
for ((i = 1; i <= 3; i++)); do
    sleep 3
    if [[ $(sudo systemctl is-active docker) != "active" ]]; then
        show 3 "Docker is not running, attempting to start..."
        sudo systemctl start docker
    else
        break
    fi
done

show 2 "Running hello-world to confirm install..."
sudo docker run hello-world

show 0 "Docker installed and verified."
show 3 "If this is the first install, add your user to the docker group: sudo usermod -aG docker \$USER, then log out/in."
