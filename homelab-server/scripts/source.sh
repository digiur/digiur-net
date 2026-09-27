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
readonly ROMM_ENV_FILE="$REPO_ROOT/docker/romm/.env"
readonly ROMM_ENV_TEMPLATE="$REPO_ROOT/docker/romm/.env.template"
readonly LIBRESPEED_ENV_FILE="$REPO_ROOT/docker/librespeed/.env"
readonly MEALIE_ENV_FILE="$REPO_ROOT/docker/mealie/.env"

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

Ensure_Env_File_From_Template() {
    local env_file="$1"
    local env_template="$2"

    if [[ -f "$env_file" ]]; then
        return
    fi

    if [[ ! -f "$env_template" ]]; then
        show 1 "Template '$env_template' not found for '$env_file'."
    fi

    cp "$env_template" "$env_file"
}

Get_Env_Value() {
    local env_file="$1"
    local key="$2"
    local line

    if [[ ! -f "$env_file" ]]; then
        return
    fi

    line=$(grep -E "^${key}=" "$env_file" | tail -n 1 || true)

    if [[ -n "$line" ]]; then
        printf '%s' "${line#*=}"
    fi
}

Set_Env_Value() {
    local env_file="$1"
    local key="$2"
    local value="$3"
    local escaped_value

    mkdir -p "$(dirname "$env_file")"
    touch "$env_file"
    escaped_value=$(printf '%s' "$value" | sed -e 's/[&|]/\\&/g')

    if grep -qE "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*$|${key}=${escaped_value}|" "$env_file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$env_file"
    fi
}

Ensure_Env_Value() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    if [[ -z "$(Get_Env_Value "$env_file" "$key")" ]]; then
        Set_Env_Value "$env_file" "$key" "$value"
    fi
}

Generate_Random_Alnum() {
    local length="$1"

    if command -v openssl &>/dev/null; then
        openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$length"
        return
    fi

    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

Generate_Random_Hex() {
    local length="$1"

    if command -v openssl &>/dev/null; then
        openssl rand -hex $((length / 2))
        return
    fi

    LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c "$length"
}

Get_Host_IP() {
    local host_ip

    host_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7; exit}')

    if [[ -z "$host_ip" ]]; then
        host_ip=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
    fi

    printf '%s' "$host_ip"
}

Get_Default_Tailscale_Hostname() {
    local raw_name

    raw_name=$(hostname | tr '[:upper:]' '[:lower:]')
    raw_name=$(printf '%s' "$raw_name" | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//')

    if [[ -z "$raw_name" ]]; then
        raw_name="digiur-net"
    fi

    printf '%s' "$raw_name"
}

Generate_Default_Env_Files() {
    local host_ip

    Ensure_Env_File_From_Template "$TRANSMISSION_ENV_FILE" "$REPO_ROOT/docker/transmission-plus-gluetun/.env.template"
    Ensure_Env_File_From_Template "$FOUNDRY_ENV_FILE" "$REPO_ROOT/docker/foundryvtt/.env.template"
    Ensure_Env_File_From_Template "$TAILSCALE_ENV_FILE" "$REPO_ROOT/docker/tailscale/.env.template"
    Ensure_Env_File_From_Template "$ROMM_ENV_FILE" "$ROMM_ENV_TEMPLATE"

    host_ip=$(Get_Host_IP)

    if [[ -z "$host_ip" ]]; then
        show 1 "Unable to determine host IP for generated defaults."
    fi

    Set_Env_Value "$MEALIE_ENV_FILE" "MEALIE_BASE_URL" "http://$host_ip:9925"

    Set_Env_Value "$TRANSMISSION_ENV_FILE" "DESIRED_TRANSMISSION_USER" "transmission"
    Ensure_Env_Value "$FOUNDRY_ENV_FILE" "FOUNDRY_ADMIN_KEY" "$(Generate_Random_Hex 64)"
    Ensure_Env_Value "$TAILSCALE_ENV_FILE" "TS_HOSTNAME" "$(Get_Default_Tailscale_Hostname)"
    Ensure_Env_Value "$LIBRESPEED_ENV_FILE" "LIBRESPEED_PASSWORD" "$(Generate_Random_Alnum 24)"
    Ensure_Env_Value "$ROMM_ENV_FILE" "ROMM_AUTH_SECRET_KEY" "$(Generate_Random_Hex 64)"
    Ensure_Env_Value "$ROMM_ENV_FILE" "ROMM_DB_PASSWORD" "$(Generate_Random_Alnum 24)"
    Ensure_Env_Value "$ROMM_ENV_FILE" "ROMM_DB_ROOT_PASSWORD" "$(Generate_Random_Alnum 24)"
}

Show_Config_File_Summary() {
    show 2 "Service env files: $TRANSMISSION_ENV_FILE, $FOUNDRY_ENV_FILE, $TAILSCALE_ENV_FILE, $ROMM_ENV_FILE, $LIBRESPEED_ENV_FILE, $MEALIE_ENV_FILE"
}

Validate_Preconditions() {
    local required_paths=(
        /storage
        /storage/media
        /storage/media/downloads
        /storage/media/downloads/raw
        /storage/tv
        /storage/movies
        /storage/roms
    )
    local missing_paths=()
    local path

    for path in "${required_paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            missing_paths+=("$path")
        fi
    done

    if (( ${#missing_paths[@]} > 0 )); then
        show 1 "Required storage paths are missing: ${missing_paths[*]}. Complete the README storage setup, then rerun install.sh."
    fi

    if [[ ! -e /dev/dri ]]; then
        show 3 "/dev/dri is missing. Jellyfin and HandBrake hardware acceleration will not be available."
    fi

    if [[ ! -e /dev/net/tun ]]; then
        show 1 "/dev/net/tun is missing. Gluetun and Tailscale require it, so install cannot continue."
    fi
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

Compose_With_Service_Env() {
    local compose_file="$1"
    shift

    local service_dir
    local service_env_file
    local compose_cmd=(docker compose)

    service_dir="$(dirname "$compose_file")"
    service_env_file="$service_dir/.env"

    if [[ -f "$service_env_file" ]]; then
        compose_cmd+=(--env-file "$service_env_file")
    fi

    compose_cmd+=(-f "$compose_file")
    compose_cmd+=("$@")
    "${compose_cmd[@]}"
}

Validate_Service_Compose() {
    local svc="$1"
    local compose_file="$2"

    show 2 "Validating compose config for service '$svc'..."
    GreyStart
    Compose_With_Service_Env "$compose_file" config >/dev/null
    ColorReset
}

Check_Service_Runtime_Status() {
    local svc="$1"
    local compose_file="$2"
    local ps_output

    ps_output=$(Compose_With_Service_Env "$compose_file" ps --format json 2>/dev/null || true)

    if [[ -z "$ps_output" ]]; then
        show 3 "Unable to determine runtime status for service '$svc'. Check it manually with 'cd docker/$svc; docker compose ps'."
        return
    fi

    if printf '%s' "$ps_output" | grep -qi '"State":"running"'; then
        show 0 "Service '$svc' has running containers."
        return
    fi

    show 3 "Service '$svc' does not appear to have any running containers. Check it with 'cd docker/$svc; docker compose ps' and inspect logs if needed."
}

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

        Validate_Service_Compose "$svc" "$compose_file"

        if Compose_With_Service_Env "$compose_file" ps --status running -q | grep -q .; then
            show 2 "Service $svc is already running - applying compose updates..."
        else
            show 2 "Service $svc is not running - starting..."
        fi

        GreyStart
        Compose_With_Service_Env "$compose_file" up -d
        ColorReset

        Check_Service_Runtime_Status "$svc" "$compose_file"
    done
}

Validate_Transmission_Creds() {
    show 2 "Checking Transmission + Gluetun credentials in $TRANSMISSION_ENV_FILE..."
    Validate_Required_Env_Values \
        "$TRANSMISSION_ENV_FILE" \
        "Transmission + Gluetun" \
        PROTON_VPN_USER PROTON_VPN_PASS DESIRED_TRANSMISSION_PASS
}

Validate_Foundry_Creds() {
    show 2 "Checking FoundryVTT credentials in $FOUNDRY_ENV_FILE..."
    Validate_Required_Env_Values \
        "$FOUNDRY_ENV_FILE" \
        "FoundryVTT" \
        FOUNDRY_USERNAME FOUNDRY_PASSWORD
}

Validate_Tailscale_Creds() {
    show 2 "Checking Tailscale credentials in $TAILSCALE_ENV_FILE..."
    Validate_Required_Env_Values \
        "$TAILSCALE_ENV_FILE" \
        "Tailscale" \
        TS_AUTHKEY
}

Validate_Romm_Creds() {
    show 2 "Checking RomM credentials in $ROMM_ENV_FILE..."
    Validate_Required_Env_Values \
        "$ROMM_ENV_FILE" \
        "RomM" \
        IGDB_CLIENT_ID IGDB_CLIENT_SECRET
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
    Validate_Romm_Creds
}

Handle_Dashy_IP_Config() {
    HOST_IP=$(Get_Host_IP)
    DASHY_TEMPLATE="$REPO_ROOT/docker/dashy/app/user-data/conf.yml.template"
    DASHY_CONF="$REPO_ROOT/docker/dashy/app/user-data/conf.yml"

    show 2 "Updating Dashy IP configuration with IP: $HOST_IP..."

    if [ -f "$DASHY_TEMPLATE" ]; then
        if [[ ! -f "$DASHY_CONF" ]]; then
            cp "$DASHY_TEMPLATE" "$DASHY_CONF"
        fi

        if grep -q '{{HOST_IP}}' "$DASHY_CONF"; then
            sed -i "s|{{HOST_IP}}|$HOST_IP|g" "$DASHY_CONF"
            show 0 "Dashy conf generated with IP: $HOST_IP"
        else
            show 2 "Dashy conf already exists. Leaving existing config unchanged."
        fi
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