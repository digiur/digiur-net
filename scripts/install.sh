#!/usr/bin/bash

LOG_FILE="install_digiur_log.txt"

# Function to log messages
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

# Function to handle errors and exit
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

Digiur_Net_Setup || handle_error "Failed to set up digiur-net"
log "Digiur-net setup completed successfully."

# Step 4: Clear terminal and show the welcome banner
log "Step 4: Clearing terminal and showing welcome banner..."
clear || handle_error "Failed to clear the terminal"

Welcome_Banner || handle_error "Failed to display welcome banner"
log "Welcome banner displayed successfully."

log "INSTALL process completed successfully."
