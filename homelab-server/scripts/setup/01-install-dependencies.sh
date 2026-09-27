#!/usr/bin/env bash
###############################################################################
# One-time/occasional: install host apt dependencies. Rerun after a fresh   #
# OS install or if one of these packages goes missing.                     #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"

readonly DEPEND_PACKAGES=('btop' 'ttyd' 'curl' 'samba' 'net-tools' 'ca-certificates' 'inotify-tools')
readonly DEPEND_COMMANDS=('btop' 'ttyd' 'curl' 'smbd' 'netstat' 'update-ca-certificates' 'inotifywait')

show 2 "Updating package manager..."
sudo apt-get update -y

for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
    cmd=${DEPEND_COMMANDS[i]}
    if ! command -v "$cmd" &>/dev/null; then
        pkg=${DEPEND_PACKAGES[i]}
        show 2 "Installing dependency: $pkg"
        sudo apt-get -y install "$pkg" --no-upgrade
    fi
done

for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
    cmd=${DEPEND_COMMANDS[i]}
    if ! command -v "$cmd" &>/dev/null; then
        show 1 "Dependency '${DEPEND_PACKAGES[i]}' installation failed, please try again manually."
    fi
done

show 0 "All dependencies installed."
