#!/bin/bash

LOG_FILE="quickstart_log.txt"

# Function to log messages
logqs() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $LOG_FILE
}

# Create the 'docker' group if it doesn't already exist (only needed once)
logqs "Checking if 'docker' group exists..."
if getent group docker > /dev/null 2>&1; then
    logqs "'docker' group already exists."
else
    logqs "Creating 'docker' group..."
    if sudo groupadd docker; then
        logqs "'docker' group created successfully."
    else
        logqs "Failed to create 'docker' group."
        exit 1
    fi
fi

# Add the current user to the 'docker' group
logqs "Adding the current user to the 'docker' group..."
if groups $USER | grep &>/dev/null '\bdocker\b'; then
    logqs "User '$USER' is already a member of the 'docker' group."
else
    if sudo usermod -aG docker $USER; then
        logqs "User '$USER' added to 'docker' group successfully."
    else
        logqs "Failed to add user '$USER' to 'docker' group."
        exit 1
    fi
fi

# Apply the group change immediately (optional)
logqs "Applying the group change immediately..."
if newgrp docker; then
    logqs "Group change applied successfully."
else
    logqs "Failed to apply group change."
    exit 1
fi

# Clone the 'digiur-net' repository
REPO_DIR="digiur-net"
if [ -d "$REPO_DIR" ]; then
    logqs "'$REPO_DIR' already exists. Skipping git clone."
else
    logqs "Cloning 'digiur-net' repository from GitHub..."
    if git clone https://github.com/digiur/digiur-net.git; then
        logqs "'digiur-net' repository cloned successfully."
    else
        logqs "Failed to clone 'digiur-net' repository."
        exit 1
    fi
fi

# Make the 'install.sh' script executable
INSTALL_SCRIPT="./digiur-net/scripts/install.sh"
logqs "Making '$INSTALL_SCRIPT' executable..."
if [ -f "$INSTALL_SCRIPT" ]; then
    if chmod +x "$INSTALL_SCRIPT"; then
        logqs "'$INSTALL_SCRIPT' made executable successfully."
    else
        logqs "Failed to make '$INSTALL_SCRIPT' executable."
        exit 1
    fi
else
    logqs "'$INSTALL_SCRIPT' not found."
    exit 1
fi

# Run the 'install.sh' script
logqs "Running '$INSTALL_SCRIPT'..."
if $INSTALL_SCRIPT &>> $LOG_FILE; then
    logqs "'$INSTALL_SCRIPT' executed successfully."
else
    logqs "Failed to execute '$INSTALL_SCRIPT'. Check the log for details."
    exit 1
fi
