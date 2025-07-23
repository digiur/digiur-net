#!/bin/bash

LOG_FILE="quickstart_log.txt"

log() {
    echo "[ digiur-net ] $1" | tee -a $LOG_FILE
}
log_date() {
    log "$(date +"%Y-%m-%d %H:%M:%S")"
}

log_date

# Clone the 'digiur-net' repository
REPO_DIR="digiur-net"
if [ -d "$REPO_DIR" ]; then
    log "'$REPO_DIR' already exists. Skipping git clone."
else
    log "Cloning 'digiur-net' repository from GitHub..."
    if git clone https://github.com/digiur/digiur-net.git "$REPO_DIR"; then
        log "'digiur-net' repository cloned successfully."
    else
        log "Failed to clone 'digiur-net' repository."
        exit 1
    fi
fi

# Make the 'quickstart.sh' script executable
QS_SCRIPT="$REPO_DIR/scripts/quickstart.sh"
log "Making '$QS_SCRIPT' executable..."
if [ -f "$QS_SCRIPT" ]; then
    if chmod +x "$QS_SCRIPT"; then
        log "'$QS_SCRIPT' made executable successfully."
    else
        log "Failed to make '$QS_SCRIPT' executable."
        exit 1
    fi
else
    log "'$QS_SCRIPT' not found."
    exit 1
fi

# Check if user is already in 'docker' group
if groups $USER | grep &>/dev/null '\bdocker\b'; then
    log "User '$USER' is already in the 'docker' group. Skipping group setup."
else
    # Create the 'docker' group if it doesn't already exist
    log "Checking if 'docker' group exists..."
    if getent group docker > /dev/null 2>&1; then
        log "'docker' group already exists."
    else
        log "Creating 'docker' group..."
        if sudo groupadd docker; then
            log "'docker' group created successfully."
        else
            log "Failed to create 'docker' group."
            exit 1
        fi
    fi

    # Add the current user to the 'docker' group
    log "Adding the current user to the 'docker' group..."
    if sudo usermod -aG docker $USER; then
        log "User '$USER' added to 'docker' group successfully."
    else
        log "Failed to add user '$USER' to 'docker' group."
        exit 1
    fi

    log "Group change will be applied after logging out and back in."
    log "Please log out and log back in to apply the group change, then rerun this script locally like `$QS_SCRIPT` to complete installation."
    exit 0
fi

log_date

# edit .env file for transmission-plus-gluetun
ENV_FILE="./digiur-net/docker/transmission-plus-gluetun/.env"
log "Checking credentials in $ENV_FILE..."
if [ ! -f "$ENV_FILE" ]; then
    log "Error: Credentials file '$ENV_FILE' not found. It should have been included in the repository."
    exit 1
fi
source "$ENV_FILE"
if [[ -z "$PROTON_VPN_USER" || -z "$PROTON_VPN_PASS" || -z "$DESIRED_TRANSMISSION_USER" || -z "$DESIRED_TRANSMISSION_PASS" ]]; then
    log "Some required credentials are missing or empty in '$ENV_FILE'. Opening it for editing..."
    ${EDITOR:-nano} "$ENV_FILE"
    source "$ENV_FILE"
    if [[ -z "$PROTON_VPN_USER" || -z "$PROTON_VPN_PASS" || -z "$DESIRED_TRANSMISSION_USER" || -z "$DESIRED_TRANSMISSION_PASS" ]]; then
        log "One or more credentials are still missing. Please complete the .env file before rerunning the script."
        exit 1
    else
        log "All required credentials found. Continuing..."
    fi
else
    log "All required credentials found in the .env file."
fi

# Make the 'install.sh' script executable
INSTALL_SCRIPT="$REPO_DIR/scripts/install.sh"
log "Making '$INSTALL_SCRIPT' executable..."
if [ -f "$INSTALL_SCRIPT" ]; then
    if chmod +x "$INSTALL_SCRIPT"; then
        log "'$INSTALL_SCRIPT' made executable successfully."
    else
        log "Failed to make '$INSTALL_SCRIPT' executable."
        exit 1
    fi
else
    log "'$INSTALL_SCRIPT' not found."
    exit 1
fi

log_date

# Run the 'install.sh' script
log "Running '$INSTALL_SCRIPT'..."
if (cd "$REPO_DIR" && ./scripts/install.sh); then
    log "'$INSTALL_SCRIPT' executed successfully."
else
    log "Failed to execute '$INSTALL_SCRIPT'. Check the log for details."
    exit 1
fi

log_date
