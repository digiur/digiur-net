#!/usr/bin/env bash
###############################################################################
# One-time/occasional: install the watch-gluetun-port systemd service.     #
# Rerun after moving the repo (it bakes in an absolute REPO_ROOT path) or   #
# changing the install user.                                               #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"

SERVICE_TEMPLATE="$REPO_ROOT/scripts/services/watch-gluetun-port.service"
SERVICE_TARGET="/etc/systemd/system/watch-gluetun-port.service"
INSTALL_USER="${SUDO_USER:-$USER}"

[[ -f "$SERVICE_TEMPLATE" ]] || show 1 "Service template '$SERVICE_TEMPLATE' not found."

show 2 "Installing watch-gluetun-port systemd service for user '$INSTALL_USER' at '$REPO_ROOT'..."

repo_root_escaped=$(printf '%s\n' "$REPO_ROOT" | sed 's/[&]/\\&/g')

sed \
    -e "s|__INSTALL_USER__|$INSTALL_USER|g" \
    -e "s|__REPO_ROOT__|$repo_root_escaped|g" \
    "$SERVICE_TEMPLATE" | sudo tee "$SERVICE_TARGET" >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable watch-gluetun-port
sudo systemctl restart watch-gluetun-port

show 0 "watch-gluetun-port service installed and running."
show 2 "Check status: sudo systemctl status watch-gluetun-port"
show 2 "Tail logs: journalctl -f -u watch-gluetun-port"
