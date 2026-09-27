#!/usr/bin/env bash

set -euo pipefail

log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

run_step() {
    local desc="$1"
    shift
    echo -e "\n\e[34m[ACTION]\e[0m $desc..."
    if "$@"; then
        log_success "$desc"
    else
        log_error "Failed to: $desc"
        exit 1
    fi
}

# Show ttyd status
run_step "Checking current ttyd.service status" sudo systemctl status ttyd.service

# Copy configuration file
run_step "Copying ttyd default config to /etc/default" sudo cp ./etc/ttyd /etc/default/ttyd

# Restart service
run_step "Restarting ttyd.service" sudo systemctl restart ttyd.service

# Check status again
run_step "Verifying ttyd.service status after restart" sudo systemctl status ttyd.service
