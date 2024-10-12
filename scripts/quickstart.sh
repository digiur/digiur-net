#!/bin/bash

LOG_FILE="quickstart_log.txt"

# Function to log messages
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

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

    # Inform user to log out/in and exit
    log "Group change will be applied after logging out and back in."
    log "Please log out and log back in to apply the group change, then rerun this script to continue."
    exit 0
fi

# Clone the 'digiur-net' repository
REPO_DIR="digiur-net"
if [ -d "$REPO_DIR" ]; then
    log "'$REPO_DIR' already exists. Skipping git clone."
else
    log "Cloning 'digiur-net' repository from GitHub..."
    if git clone https://github.com/digiur/digiur-net.git; then
        log "'digiur-net' repository cloned successfully."
    else
        log "Failed to clone 'digiur-net' repository."
        exit 1
    fi
fi

# Make the 'install.sh' script executable
INSTALL_SCRIPT="./digiur-net/scripts/install.sh"
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

# Run the 'install.sh' script
log "Running '$INSTALL_SCRIPT'..."
if $INSTALL_SCRIPT &>> $LOG_FILE; then
    log "'$INSTALL_SCRIPT' executed successfully."
else
    log "Failed to execute '$INSTALL_SCRIPT'. Check the log for details."
    exit 1
fi
