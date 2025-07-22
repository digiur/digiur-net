#!/usr/bin/bash
###############################################################################
# Shell and Logging Helpers                                                   #
###############################################################################
echo -e "\e[0m\c"
set -e

LOG_FILE="install_log.txt"

readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green  	| Lines, bullets and separators
    '\e[1m'        # Bold white	| Main descriptions
    '\e[90m'       # Grey		| Credits
    '\e[91m'       # Red		| Update notifications Alert
    '\e[33m'       # Yellow		| Emphasis
)

readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
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
# Install Package Dependencies                                                #
###############################################################################
readonly DEPEND_PACKAGES=('btop' 'ttyd' 'curl' 'samba' 'net-tools' 'ca-certificates')
readonly DEPEND_COMMANDS=('btop' 'ttyd' 'curl' 'smbd' 'netstat' 'update-ca-certificates')

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
            show 4 "Docker is not running, try to start"
            sudo systemctl start docker
        else
            break
        fi
    done
}

###############################################################################
# Welcome Helpers                                                             #
###############################################################################
echo_ips() {
    # List all non-loopback IPv4 addresses for all interfaces
    local ips
    ips=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {print $2}' | cut -d/ -f1)
    for ip in $ips; do
        echo -e "${GREEN_BULLET} http://$ip"
    done
}

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
    echo_ips
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}DigiurOS on Github  : https://github.com/digiur/digiur-net"
    echo -e " ${aCOLOUR[2]}DigiurOS Discord    : https://discord.gg/CBFae73u"
    echo -e ""
    echo -e "${COLOUR_RESET}"
}

###############################################################################
# Swap Size                                                                   #
# See: https://help.ubuntu.com/community/SwapFaq                              #
###############################################################################
PHYSICAL_MEMORY_GB=$(LC_ALL=C free --giga | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY_GB

FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES
readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

SWAP_FILE=$(LC_ALL=C swapon --show | tail -n 1 | awk '{print $1}')
readonly SWAP_FILE
SWAP_FILE_BYTES=$(LC_ALL=C stat -c %s "$SWAP_FILE")
readonly SWAP_FILE_BYTES
readonly SWAP_FILE_GB=$((SWAP_FILE_BYTES / 1024 / 1024))

Set_Swap_Size() {
    show 2 "Turn off swap..."
    GreyStart
    sudo swapoff "$SWAP_FILE"
    ColorReset

    show 2 "Resize swap in-place..."
    GreyStart
    sudo dd if=/dev/zero of="$SWAP_FILE" count="$PHYSICAL_MEMORY_GB" bs=1G
    ColorReset

    show 2 "mkswap $SWAP_FILE..."
    GreyStart
    sudo mkswap "$SWAP_FILE"
    sudo chmod 0600 "$SWAP_FILE"
    ColorReset

    show 2 "Turn on swap..."
    GreyStart
    sudo swapon "$SWAP_FILE"
    sudo swapon --show
    ColorReset
}

###############################################################################
# Digiur Net                                                                 #
###############################################################################
Digiur_Net_Setup() {
    # local services=(
    #     alist audiobookshelf dashy handbrake jellyfin librespeed mealie memos myspeed
    #     navidrome portainer prowlarr qdirstat radarr romm snapdrop sonarr swing-music
    #     transmission-plus-gluetun uptime-kuma
    # )

    local services=(
        dashy handbrake jellyfin librespeed mealie myspeed portainer
        prowlarr qdirstat radarr romm sonarr transmission-plus-gluetun
    )

    for svc in "${services[@]}"; do
        show 2 "Start $svc..."
        GreyStart
        docker compose -f "./docker/$svc/docker-compose.yml" up -d
        ColorReset
    done
}

Handle_Transmission_Creds() {
    show 2 "Handling Transmission and VPN credentials..."
    CRED_FILE="./transmission+gluetun.env"
    if [ ! -f "$CRED_FILE" ]; then
        show 1 "Credentials file $CRED_FILE not found. Please create it and fill in Transmission and VPN credentials before running the install. See the quickstart instructions."
    fi

    source "$CRED_FILE"
    if [ -z "$TRANSMISSION_USER" ] || [ -z "$TRANSMISSION_PASS" ] || [ -z "$VPN_USER" ] || [ -z "$VPN_PASS" ]; then
        show 1 "Credentials file $CRED_FILE is missing required values. Please edit it and fill in all credentials before running the install."
    fi

    TRANSMISSION_TEMPLATE="./docker/transmission-plus-gluetun/docker-compose.yml.template"
    TRANSMISSION_COMPOSE="./docker/transmission-plus-gluetun/docker-compose.yml"

    cp "$TRANSMISSION_TEMPLATE" "$TRANSMISSION_COMPOSE"

    sed -i "s|{{TRANSMISSION_USER}}|$TRANSMISSION_USER|g" "$TRANSMISSION_COMPOSE"
    sed -i "s|{{TRANSMISSION_PASS}}|$TRANSMISSION_PASS|g" "$TRANSMISSION_COMPOSE"
    sed -i "s|{{VPN_USER}}|$VPN_USER|g" "$TRANSMISSION_COMPOSE"
    sed -i "s|{{VPN_PASS}}|$VPN_PASS|g" "$TRANSMISSION_COMPOSE"
}

Handle_Dashy_IP_Config() {
    HOST_IP=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
    DASHY_TEMPLATE="./docker/dashy/app/user-data/conf.yml.template"
    DASHY_CONF="./docker/dashy/app/user-data/conf.yml"

    show 2 "Updating Dashy IP configuration with IP: $HOST_IP..."

    if [ -f "$DASHY_TEMPLATE" ]; then
        cp "$DASHY_TEMPLATE" "$DASHY_CONF"
        sed -i "s|{{HOST_IP}}|$HOST_IP|g" "$DASHY_CONF"
        show 0 "Dashy conf generated with IP: $HOST_IP"
    else
        show 1 "Template file $DASHY_TEMPLATE not found"
    fi
}