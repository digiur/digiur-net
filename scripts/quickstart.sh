#!/bin/bash
set -euo pipefail

LOG_FILE="quickstart_log.txt"

log() {
    echo "[ digiur-net ] $1" | tee -a $LOG_FILE
}

log_section() {
    log ""
    log "=== $1 ==="
}

log_date() {
    log "$(date +"%Y-%m-%d %H:%M:%S")"
}

ensure_env_file_from_template() {
    local env_file="$1"
    local env_template="$2"

    if [ -f "$env_file" ]; then
        return
    fi

    if [ -f "$env_template" ]; then
        cp "$env_template" "$env_file"
        log "Created '$env_file' from template."
    else
        log "Error: '$env_file' is missing and template '$env_template' was not found."
        exit 1
    fi
}

validate_env_values() {
    local env_file="$1"
    local env_name="$2"
    shift 2

    local required_vars=("$@")
    local missing=()
    local var_name
    local required_list

    required_list="${required_vars[*]}"

    log "$env_name requires: $required_list"

    # shellcheck disable=SC1090
    source "$env_file"

    for var_name in "${required_vars[@]}"; do
        if [[ -z "${!var_name:-}" ]]; then
            missing+=("$var_name")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        log "$env_name is missing required values (${missing[*]}). Opening '$env_file' for editing..."
        log "Save and close the editor when done, then quickstart will re-check automatically."
        ${EDITOR:-nano} "$env_file"

        # shellcheck disable=SC1090
        source "$env_file"
        missing=()

        for var_name in "${required_vars[@]}"; do
            if [[ -z "${!var_name:-}" ]]; then
                missing+=("$var_name")
            fi
        done

        if (( ${#missing[@]} > 0 )); then
            log "$env_name still has missing values (${missing[*]}). Complete '$env_file' and rerun quickstart."
            exit 1
        fi
    fi

    log "$env_name credentials/config look good."
}

log_date

# Clone the 'digiur-net' repository
REPO_DIR="digiur-net"
if [ -d ".git" ] && [ -f "./scripts/install.sh" ]; then
    REPO_DIR="."
    log "Running from inside an existing digiur-net repository."
elif [ -d "$REPO_DIR" ]; then
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
chmod +x ./$REPO_DIR/scripts/*
REPO_DIR_ABS="$(cd "$REPO_DIR" && pwd)"
QS_SCRIPT="$REPO_DIR_ABS/scripts/quickstart.sh"
INSTALL_SCRIPT="$REPO_DIR_ABS/scripts/install.sh"

log_date

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
    log "Please log out and log back in to apply the group change, then rerun this script locally like '$QS_SCRIPT' to complete installation."
    exit 0
fi

log_date

TRANSMISSION_ENV_FILE="$REPO_DIR_ABS/docker/transmission-plus-gluetun/.env"
TRANSMISSION_ENV_TEMPLATE="$REPO_DIR_ABS/docker/transmission-plus-gluetun/.env.template"
FOUNDRY_ENV_FILE="$REPO_DIR_ABS/docker/foundryvtt/.env"
FOUNDRY_ENV_TEMPLATE="$REPO_DIR_ABS/docker/foundryvtt/.env.template"
TAILSCALE_ENV_FILE="$REPO_DIR_ABS/docker/tailscale/.env"
TAILSCALE_ENV_TEMPLATE="$REPO_DIR_ABS/docker/tailscale/.env.template"

log_section "Preparing default stack env files"
ensure_env_file_from_template "$TRANSMISSION_ENV_FILE" "$TRANSMISSION_ENV_TEMPLATE"
ensure_env_file_from_template "$FOUNDRY_ENV_FILE" "$FOUNDRY_ENV_TEMPLATE"
ensure_env_file_from_template "$TAILSCALE_ENV_FILE" "$TAILSCALE_ENV_TEMPLATE"

log_section "Configuring Transmission + Gluetun"
validate_env_values \
    "$TRANSMISSION_ENV_FILE" \
    "Transmission + Gluetun" \
    PROTON_VPN_USER PROTON_VPN_PASS DESIRED_TRANSMISSION_USER DESIRED_TRANSMISSION_PASS

log_section "Configuring FoundryVTT"
validate_env_values \
    "$FOUNDRY_ENV_FILE" \
    "FoundryVTT" \
    FOUNDRY_USERNAME FOUNDRY_PASSWORD FOUNDRY_ADMIN_KEY

log_section "Configuring Tailscale"
validate_env_values \
    "$TAILSCALE_ENV_FILE" \
    "Tailscale" \
    TS_AUTHKEY TS_HOSTNAME

log_date

# Run the 'install.sh' script
log "Running '$INSTALL_SCRIPT'..."
if (cd "$REPO_DIR_ABS" && ./scripts/install.sh); then
    log "'$INSTALL_SCRIPT' executed successfully."
else
    log "Failed to execute '$INSTALL_SCRIPT'. Check the log for details."
    exit 1
fi

log_date
