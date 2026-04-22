#!/usr/bin/bash
###############################################################################
# Shell and Logging Helpers                                                   #
###############################################################################
echo -e "\e[0m\c"
set -e

LOG_FILE="install_log.txt"
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ACTIVE_SERVICES_FILE="$REPO_ROOT/scripts/services/active-services.txt"
readonly TRANSMISSION_ENV_FILE="$REPO_ROOT/docker/transmission-plus-gluetun/.env"
readonly FOUNDRY_ENV_FILE="$REPO_ROOT/docker/foundryvtt/.env"
readonly TAILSCALE_ENV_FILE="$REPO_ROOT/docker/tailscale/.env"

readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green  	| Lines, bullets and separators
    '\e[1m'        # Bold white	| Main descriptions
    '\e[90m'       # Grey		| Credits
    '\e[91m'       # Red		| Update notifications Alert
    '\e[33m'       # Yellow		| Emphasis
)

readonly GREEN_LINE=" ${aCOLOUR[0]}-----------------------------------------------------$COLOUR_RESET"
readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"

# Trap Ctrl+C to exit gracefully
trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

show() {
    # OK
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}    OK    $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2" | tee -a $LOG_FILE
    # FAILED
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}  FAILED  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2" | tee -a $LOG_FILE
        exit 1
    # INFO
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}   INFO   $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2" | tee -a $LOG_FILE
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}  NOTICE  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2" | tee -a $LOG_FILE
    fi
}

show_time() {
    show 2 "$(date +"%Y-%m-%d %H:%M:%S")"
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

###############################################################################
# Welcome Helpers                                                             #
###############################################################################
readonly IP=$(ip route get 1.1.1.1 | awk '/src/ {print $7}')

Welcome_Logo() {
    echo '
     ____                          __    _____
    |  __ \                      / __ \ / ____|
    | |  \ \ _   _   _ _  _  __ | |  | | (___
    | |   | |_|/ _ \|_| || |/ _\| |  | |\___ \
    | |__/ /| | (_| | | || | |  | |__| |____) |
    |_____/ |_|\_  /|_|\_,_|_|   \____/|_____/
             |____/
'
}

Welcome_Banner() {
    Welcome_Logo
    echo "INSTALL COMPLETE!"
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " DigiurOS ${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    echo -e "${GREEN_BULLET} http://$IP"
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}DigiurOS on Github  : https://github.com/digiur/digiur-net"
    echo -e " ${aCOLOUR[2]}DigiurOS Discord    : https://discord.gg/CBFae73u"
    echo -e ""
    echo -e "${COLOUR_RESET}"
}

###############################################################################
# Install Package Dependencies                                                #
###############################################################################
readonly DEPEND_PACKAGES=('btop' 'ttyd' 'curl' 'samba' 'net-tools' 'ca-certificates' 'inotify-tools')
readonly DEPEND_COMMANDS=('btop' 'ttyd' 'curl' 'smbd' 'netstat' 'update-ca-certificates' 'inotifywait')

Install_Depends() {
    for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
        local cmd=${DEPEND_COMMANDS[i]}
        if ! command -v "$cmd" &>/dev/null; then
            local packageNeeded=${DEPEND_PACKAGES[i]}
            show 2 "Install the necessary dependency: \e[33m$packageNeeded \e[0m"
            GreyStart
            sudo apt-get -y install "$packageNeeded" --no-upgrade
            ColorReset
        fi
    done
}

Check_Dependency_Installation() {
    for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
        local cmd=${DEPEND_COMMANDS[i]}
        if ! command -v "$cmd" &>/dev/null; then
            local packageNeeded=${DEPEND_PACKAGES[i]}
            show 1 "Dependency \e[33m$packageNeeded \e[0m installation failed, please try again manually!"
            exit 1
        fi
    done
}

Update_Package_Resource() {
    show 2 "Updating package manager..."
    GreyStart
    sudo apt-get update -y
    ColorReset
}

Upgrade_Package_Resource() {
    show 2 "Upgrading package manager..."
    GreyStart
    sudo apt-get upgrade -y
    ColorReset
}

###############################################################################
# Install Docker # https://docs.docker.com/engine/install/ubuntu/             #
###############################################################################
source /etc/os-release # for $UBUNTU_CODENAME

Install_Docker() {
    # See: https://docs.docker.com/engine/install/ubuntu/
    show 2 "Add Docker's official GPG key..."
    GreyStart
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    ColorReset

    show 2 "Add the repository to Apt sources..."
    GreyStart
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ColorReset

    show 2 "Install Packages..."
    Update_Package_Resource
    GreyStart
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ColorReset
}

Check_Docker_Install() {
    show 2 "Verify install..."
    GreyStart
    Check_Docker_Running
    sudo docker run hello-world
    ColorReset
}

Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if [[ $(sudo systemctl is-active docker) != "active" ]]; then
            show 3 "Docker is not running, try to start"
            sudo systemctl start docker
        else
            break
        fi
    done
}

###############################################################################
# Swap Size                                                                   #
# See: https://help.ubuntu.com/community/SwapFaq                              #
###############################################################################
readonly PHYSICAL_MEMORY_GB=$(LC_ALL=C free --giga | awk '/Mem:/ { print $2 }')

readonly FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

readonly SWAP_FILE=$(LC_ALL=C swapon --show | tail -n 1 | awk '{print $1}')
readonly SWAP_FILE_BYTES=$(LC_ALL=C stat -c %s "$SWAP_FILE")
readonly SWAP_FILE_GB=$((SWAP_FILE_BYTES / 1024 / 1024))

readonly TARGET_SWAP_BY_DISK=$((FREE_DISK_GB / 4))

# Use smaller of the two
if (( PHYSICAL_MEMORY_GB < TARGET_SWAP_BY_DISK )); then
    TARGET_SWAP_GB=$PHYSICAL_MEMORY_GB
else
    TARGET_SWAP_GB=$TARGET_SWAP_BY_DISK
fi
readonly TARGET_SWAP_GB

Set_Swap_Size() {
    if (( SWAP_FILE_GB >= TARGET_SWAP_GB )); then
        show 0 "Swap file is already ${SWAP_FILE_GB}GB, which is >= target ${TARGET_SWAP_GB}GB. Skipping resize."
        return
    fi

    show 2 "Turning off swap..."
    GreyStart
    sudo swapoff "$SWAP_FILE"
    ColorReset

    show 2 "Resizing swap to ${TARGET_SWAP_GB}GB in-place..."
    GreyStart
    sudo dd if=/dev/zero of="$SWAP_FILE" count="$TARGET_SWAP_GB" bs=1G status=progress
    ColorReset

    show 2 "Creating new swap space on $SWAP_FILE..."
    GreyStart
    sudo mkswap "$SWAP_FILE"
    sudo chmod 0600 "$SWAP_FILE"
    ColorReset

    show 2 "Turning on swap..."
    GreyStart
    sudo swapon "$SWAP_FILE"
    sudo swapon --show
    ColorReset
}

###############################################################################
# Digiur Net                                                                 #
###############################################################################
ACTIVE_SERVICES=()

Load_Active_Services() {
    if [[ ! -f "$ACTIVE_SERVICES_FILE" ]]; then
        show 1 "Active services file '$ACTIVE_SERVICES_FILE' not found."
    fi

    mapfile -t ACTIVE_SERVICES < <(grep -Ev '^\s*(#|$)' "$ACTIVE_SERVICES_FILE")

    if (( ${#ACTIVE_SERVICES[@]} == 0 )); then
        show 1 "No active services were found in '$ACTIVE_SERVICES_FILE'."
    fi
}

Digiur_Net_Setup() {
    local svc
    local compose_file

    Load_Active_Services

    for svc in "${ACTIVE_SERVICES[@]}"; do
        compose_file="$REPO_ROOT/docker/$svc/docker-compose.yml"

        if [[ ! -f "$compose_file" ]]; then
            show 1 "Compose file missing for service '$svc': $compose_file"
        fi

        if docker compose -f "$compose_file" ps --status running -q | grep -q .; then
            show 2 "Service $svc is already running - applying compose updates..."
        else
            show 2 "Service $svc is not running - starting..."
        fi

        GreyStart
        docker compose -f "$compose_file" up -d
        ColorReset
    done
}

Validate_Transmission_Creds() {
    show 2 "Checking Transmission + Gluetun credentials in $TRANSMISSION_ENV_FILE..."
    Validate_Required_Env_Values \
        "$TRANSMISSION_ENV_FILE" \
        "Transmission + Gluetun" \
        PROTON_VPN_USER PROTON_VPN_PASS DESIRED_TRANSMISSION_USER DESIRED_TRANSMISSION_PASS
}

Validate_Foundry_Creds() {
    show 2 "Checking FoundryVTT credentials in $FOUNDRY_ENV_FILE..."
    Validate_Required_Env_Values \
        "$FOUNDRY_ENV_FILE" \
        "FoundryVTT" \
        FOUNDRY_USERNAME FOUNDRY_PASSWORD FOUNDRY_ADMIN_KEY
}

Validate_Tailscale_Creds() {
    show 2 "Checking Tailscale credentials in $TAILSCALE_ENV_FILE..."
    Validate_Required_Env_Values \
        "$TAILSCALE_ENV_FILE" \
        "Tailscale" \
        TS_AUTHKEY TS_HOSTNAME
}

Validate_Required_Env_Values() {
    local env_file="$1"
    local env_name="$2"
    shift 2

    local required_vars=("$@")
    local missing=()
    local var_name

    if [[ ! -f "$env_file" ]]; then
        show 1 "Required env file '$env_file' not found for $env_name."
    fi

    # shellcheck disable=SC1090
    source "$env_file"

    for var_name in "${required_vars[@]}"; do
        if [[ -z "${!var_name:-}" ]]; then
            missing+=("$var_name")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        show 1 "Missing required values in '$env_file' for $env_name: ${missing[*]}"
    fi

    show 0 "$env_name env values look good."
}

Validate_Default_Stack_Creds() {
    Validate_Transmission_Creds
    Validate_Foundry_Creds
    Validate_Tailscale_Creds
}

Handle_Dashy_IP_Config() {
    HOST_IP=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
    DASHY_TEMPLATE="$REPO_ROOT/docker/dashy/app/user-data/conf.yml.template"
    DASHY_CONF="$REPO_ROOT/docker/dashy/app/user-data/conf.yml"

    show 2 "Updating Dashy IP configuration with IP: $HOST_IP..."

    if [ -f "$DASHY_TEMPLATE" ]; then
        cp "$DASHY_TEMPLATE" "$DASHY_CONF"
        sed -i "s|{{HOST_IP}}|$HOST_IP|g" "$DASHY_CONF"
        show 0 "Dashy conf generated with IP: $HOST_IP"
    else
        show 1 "Template file $DASHY_TEMPLATE not found"
    fi
}

Install_Gluetun_Port_Watcher_Service() {
    local service_template="$REPO_ROOT/scripts/services/watch-gluetun-port.service"
    local service_target="/etc/systemd/system/watch-gluetun-port.service"
    local install_user="${SUDO_USER:-$USER}"
    local repo_root_escaped

    if [[ ! -f "$service_template" ]]; then
        show 1 "Service template '$service_template' not found."
    fi

    show 2 "Installing watch-gluetun-port systemd service..."

    repo_root_escaped=$(printf '%s\n' "$REPO_ROOT" | sed 's/[&]/\\&/g')

    GreyStart
    sed \
        -e "s|__INSTALL_USER__|$install_user|g" \
        -e "s|__REPO_ROOT__|$repo_root_escaped|g" \
        "$service_template" | sudo tee "$service_target" >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable watch-gluetun-port
    sudo systemctl restart watch-gluetun-port
    ColorReset

    show 0 "watch-gluetun-port service installed and running."
}