#!/usr/bin/bash

LOG_FILE="install_log.txt"

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

handle_error() {
    log "ERROR: $1. Exiting."
    exit 1
}

# Check if source.sh exists and source it
log "Sourcing 'source.sh'..."
if [ -f "./digiur-net/scripts/source.sh" ]; then
    source ./digiur-net/scripts/source.sh || handle_error "Failed to source 'source.sh'"
    log "'source.sh' sourced successfully."
else
    handle_error "'source.sh' not found."
fi

# Welcome Logo
log "Displaying welcome logo..."
Welcome_Logo || handle_error "Failed to display welcome logo"
log "Welcome logo displayed."

log "INSTALL process started..."

# Step 0: Set Swap Size
log "Step 0: Setting swap size..."
Set_Swap_Size || handle_error "Failed to set swap size"
log "Swap size set successfully."

# Step 1: Install Dependencies
log "Step 1: Installing dependencies..."
Update_Package_Resource || handle_error "Failed to update package resource"
log "Package resource updated."

Install_Depends || handle_error "Failed to install dependencies"
log "Dependencies installed."

Check_Dependency_Installation || handle_error "Dependency installation check failed"
log "Dependency installation check passed."

# Step 2: Check and Install Docker
log "Step 2: Checking and installing Docker..."
Install_Docker || handle_error "Failed to install Docker"
log "Docker installed."

Check_Docker_Install || handle_error "Docker installation check failed"
log "Docker installation check passed."

# Step 3: Digiur-net Setup
log "Step 3: Setting up digiur-net..."
Upgrade_Package_Resource || handle_error "Failed to upgrade package resource"
log "Package resource upgraded."

Check_Dependency_Installation || handle_error "Dependency re-check failed"
log "Dependency re-check passed."

Check_Docker_Install || handle_error "Docker re-check failed"
log "Docker re-check passed."

# Handle Transmission and VPN credentials via .env file
CRED_FILE="./transmission+gluetun.env"
if [ ! -f "$CRED_FILE" ]; then
    handle_error "Credentials file $CRED_FILE not found. Please create it and fill in Transmission and VPN credentials before running the install. See the quickstart instructions."
fi

source "$CRED_FILE"
if [ -z "$TRANSMISSION_USER" ] || [ -z "$TRANSMISSION_PASS" ] || [ -z "$VPN_USER" ] || [ -z "$VPN_PASS" ]; then
    handle_error "Credentials file $CRED_FILE is missing required values. Please edit it and fill in all credentials before running the install."
fi

TRANSMISSION_TEMPLATE="./digiur-net/docker/transmission-plus-gluetun/docker-compose.yml.template"
TRANSMISSION_COMPOSE="./digiur-net/docker/transmission-plus-gluetun/docker-compose.yml"

cp "$TRANSMISSION_TEMPLATE" "$TRANSMISSION_COMPOSE"

sed -i "s|{{TRANSMISSION_USER}}|$TRANSMISSION_USER|g" "$TRANSMISSION_COMPOSE"
sed -i "s|{{TRANSMISSION_PASS}}|$TRANSMISSION_PASS|g" "$TRANSMISSION_COMPOSE"
sed -i "s|{{VPN_USER}}|$VPN_USER|g" "$TRANSMISSION_COMPOSE"
sed -i "s|{{VPN_PASS}}|$VPN_PASS|g" "$TRANSMISSION_COMPOSE"

# Update dashboard IPs
log "Injecting host IP into Dashy config..."

HOST_IP=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
DASHY_TEMPLATE="./digiur-net/docker/dashy/app/user-data/conf.yml.template"
DASHY_CONF="./digiur-net/docker/dashy/app/user-data/conf.yml"

if [ -f "$DASHY_TEMPLATE" ]; then
    cp "$DASHY_TEMPLATE" "$DASHY_CONF"
    sed -i "s|{{HOST_IP}}|$HOST_IP|g" "$DASHY_CONF"
    log "Dashy conf generated with IP: $HOST_IP"
else
    handle_error "Template file $DASHY_TEMPLATE not found"
fi

# Start containers
Digiur_Net_Setup || handle_error "Failed to set up digiur-net"
log "Digiur-net setup completed successfully."

# Step 4: Clear terminal and show the welcome banner
log "Step 4: Clearing terminal and showing welcome banner..."
clear || handle_error "Failed to clear the terminal"

Welcome_Banner || handle_error "Failed to display welcome banner"
log "Welcome banner displayed successfully."

log "INSTALL process completed successfully."
