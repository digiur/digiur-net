#!/usr/bin/env bash
###############################################################################
# One-time/occasional: install/refresh the ttyd web terminal config.       #
# Rerun after editing etc/ttyd.                                            #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"

show 2 "Checking current ttyd.service status..."
sudo systemctl status ttyd.service --no-pager || true

show 2 "Copying ttyd default config to /etc/default/ttyd..."
sudo cp "$REPO_ROOT/etc/ttyd" /etc/default/ttyd

show 2 "Restarting ttyd.service..."
sudo systemctl restart ttyd.service

show 2 "Verifying ttyd.service status after restart..."
sudo systemctl status ttyd.service --no-pager

show 0 "ttyd configured and running."
