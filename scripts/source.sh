#!/usr/bin/bash
###############################################################################
# GOLBALS                                                                     #
###############################################################################
# shellcheck source=/dev/null
#clear
echo -e "\e[0m\c"
set -e

source /etc/os-release

# SYSTEM REQUIREMENTS
readonly MINIMUM_DOCKER_VERSION="20"
readonly DEPEND_PACKAGES=('btop' 'ttyd' 'curl' 'samba' 'net-tools' 'ca-certificates')
readonly DEPEND_COMMANDS=('btop' 'ttyd' 'curl' 'smbd' 'netstat' 'update-ca-certificates')

# MEMORY INFO
PHYSICAL_MEMORY_GB=$(LC_ALL=C free --giga | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY_GB

# DISK INFO
FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES

readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

SWAP_FILE=$(LC_ALL=C swapon --show | tail -n 1 | awk '{print $1}')
readonly SWAP_FILE

SWAP_FILE_BYTES=$(LC_ALL=C stat -c %s $SWAP_FILE)
readonly SWAP_FILE_BYTES

readonly SWAP_FILE_GB=$((SWAP_FILE_BYTES / 1024 / 1024))

LSB_DIST=$( ([ -n "${ID_LIKE}" ] && echo "${ID_LIKE}") || ([ -n "${ID}" ] && echo "${ID}"))
readonly LSB_DIST

DIST=$(echo "${ID}")
readonly DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

# COLORS
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

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

###############################################################################
# Helpers                                                                     #
###############################################################################

#######################################
# Custom printing function
# Globals:
#   None
# Arguments:
#   $1 0:OK   1:FAILED  2:INFO  3:NOTICE
#   message
# Returns:
#   None
#######################################

Show() {
    # OK
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}  OK  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # FAILED
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}FAILED$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
        exit 1
    # INFO
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]} INFO $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    fi
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

# Clear Terminal
Clear_Term() {
    # Without an input terminal, there is no point in doing this.
    [[ -t 0 ]] || return

    # Printing terminal height - 1 newlines seems to be the fastest method that is compatible with all terminal types.
    lines=$(tput lines) i newlines
    local lines

    for ((i = 1; i < ${lines% *}; i++)); do newlines+='\n'; done
    echo -ne "\e[0m$newlines\e[H"
}

###############################################################################
# Install Package Dependencies                                                #
###############################################################################
Update_Package_Resource() {
    Show 2 "Updating package manager..."
    GreyStart
    sudo apt-get update -qq
    ColorReset
    Show 0 "Update package manager complete."
}

Upgrade_Package_Resource() {
    Show 2 "Upgrading package manager..."
    GreyStart
    sudo apt-get upgrade -qq
    ColorReset
    Show 0 "Upgrade package manager complete."
}

Install_Depends() {
    for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
        cmd=${DEPEND_COMMANDS[i]}
        if [[ ! -x $(sudo which "$cmd") ]]; then
            packageNeeded=${DEPEND_PACKAGES[i]}
            Show 2 "Install the necessary dependency: \e[33m$packageNeeded \e[0m"
            GreyStart
            sudo apt-get -y -qq install "$packageNeeded" --no-upgrade
            ColorReset
        fi
    done
}

Check_Dependency_Installation() {
    for ((i = 0; i < ${#DEPEND_COMMANDS[@]}; i++)); do
        cmd=${DEPEND_COMMANDS[i]}
        if [[ ! -x $(sudo which "$cmd") ]]; then
            packageNeeded=${DEPEND_PACKAGES[i]}
            Show 1 "Dependency \e[33m$packageNeeded \e[0m installation failed, please try again manually!"
            exit 1
        fi
    done
}

###############################################################################
# Install Docker                                                              #
###############################################################################
Install_Docker() {
    Show 2 "Add Docker's official GPG key..."
    GreyStart
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    ColorReset

    Show 2 "Add the repository to Apt sources..."
    GreyStart
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ColorReset

    Show 2 "Install Packages..."
    GreyStart
    sudo apt-get update -qq
    sudo apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ColorReset

    Show 0 "Docker install complete."
}

Check_Docker_Install() {
    Show 2 "Verify install..."
    GreyStart
    Check_Docker_Running
    sudo docker run hello-world
    ColorReset
    Show 0 "Docker verify install complete."
}


Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if [[ ! $(sudo systemctl is-active docker) == "active" ]]; then
            Show 1 "Docker is not running, try to start"
            sudo systemctl start docker
        else
            break
        fi
    done
}

###############################################################################
# Welcome Helpers                                                             #
###############################################################################
Get_IPs() {
    PORT=$(sudo cat ${CASA_CONF_PATH} | grep port | sed 's/port=//')
    ALL_NIC=$($sudo_cmd ls /sys/class/net/ | grep -v "$(ls /sys/devices/virtual/net/)")
    for NIC in ${ALL_NIC}; do
        IP=$($sudo_cmd ifconfig "${NIC}" | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | sed -e 's/addr://g')
        if [[ -n $IP ]]; then
            if [[ "$PORT" -eq "80" ]]; then
                echo -e "${GREEN_BULLET} http://$IP (${NIC})"
            else
                echo -e "${GREEN_BULLET} http://$IP:$PORT (${NIC})"
            fi
        fi
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
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}DigiurOS on Github  : https://github.com/digiur/digiur-net"
    echo -e " ${aCOLOUR[2]}DigiurOS Discord    : https://discord.gg/CBFae73u"
    echo -e ""
    echo -e "${COLOUR_RESET}"
}

###############################################################################
# Swap Size                                                                        #
###############################################################################
Set_Swap_Size() {
    Show 2 "Turn off swap..."
    GreyStart
    sudo swapoff $SWAP_FILE
    ColorReset

    Show 2 "Resize swap in-place..."
    GreyStart
    sudo time sudo dd if=/dev/zero of=$SWAP_FILE count=$PHYSICAL_MEMORY_GB bs=1G
    ColorReset

    Show 2 "mkswap $SWAP_FILE..."
    GreyStart
    sudo mkswap $SWAP_FILE
    sudo chmod 0600 $SWAP_FILE
    ColorReset

    Show 2 "Turn on swap..."
    GreyStart
    sudo swapon $SWAP_FILE
    sudo swapon --show
    ColorReset
    Show 0 "Set swap size complete."
}

###############################################################################
# Digiur Repo                                                                 #
###############################################################################
Digiur_Net_Setup() {
    Show 2 "Start ttyd..."
    GreyStart
    sudo systemctl status ttyd.service
    sudo cp ./digiur-net/etc/ttyd /etc/default/ttyd
    sudo systemctl restart ttyd.service
    sudo systemctl status ttyd.service
    ColorReset

    Show 2 "Start alist..."
    GreyStart
    docker compose -f ./digiur-net/docker/alist/docker-compose.yml up -d
    ColorReset

    Show 2 "Start audiobookshelf..."
    GreyStart
    docker compose -f ./digiur-net/docker/audiobookshelf/docker-compose.yml up -d
    ColorReset

    Show 2 "Start dashy..."
    GreyStart
    docker compose -f ./digiur-net/docker/dashy/docker-compose.yml up -d
    ColorReset

    Show 2 "Start handbrake..."
    GreyStart
    docker compose -f ./digiur-net/docker/handbrake/docker-compose.yml up -d
    ColorReset

    Show 2 "Start jellyfin..."
    GreyStart
    docker compose -f ./digiur-net/docker/jellyfin/docker-compose.yml up -d
    ColorReset

    Show 2 "Start librespeed..."
    GreyStart
    docker compose -f ./digiur-net/docker/librespeed/docker-compose.yml up -d
    ColorReset

    Show 2 "Start mealie..."
    GreyStart
    docker compose -f ./digiur-net/docker/mealie/docker-compose.yml up -d
    ColorReset

    Show 2 "Start memos..."
    GreyStart
    docker compose -f ./digiur-net/docker/memos/docker-compose.yml up -d
    ColorReset

    Show 2 "Start myspeed..."
    GreyStart
    docker compose -f ./digiur-net/docker/myspeed/docker-compose.yml up -d
    ColorReset

    Show 2 "Start navidrome..."
    GreyStart
    docker compose -f ./digiur-net/docker/navidrome/docker-compose.yml up -d
    ColorReset

    Show 2 "Start portainer..."
    GreyStart
    docker compose -f ./digiur-net/docker/portainer/docker-compose.yml up -d
    ColorReset

    Show 2 "Start prowlarr..."
    GreyStart
    docker compose -f ./digiur-net/docker/prowlarr/docker-compose.yml up -d
    ColorReset

    Show 2 "Start qdirstat..."
    GreyStart
    docker compose -f ./digiur-net/docker/qdirstat/docker-compose.yml up -d
    ColorReset

    Show 2 "Start radarr..."
    GreyStart
    docker compose -f ./digiur-net/docker/radarr/docker-compose.yml up -d
    ColorReset

    Show 2 "Start romm..."
    GreyStart
    docker compose -f ./digiur-net/docker/romm/docker-compose.yml up -d
    ColorReset

    Show 2 "Start snapdrop..."
    GreyStart
    docker compose -f ./digiur-net/docker/snapdrop/docker-compose.yml up -d
    ColorReset

    Show 2 "Start sonarr..."
    GreyStart
    docker compose -f ./digiur-net/docker/sonarr/docker-compose.yml up -d
    ColorReset

    Show 2 "Start swing-music..."
    GreyStart
    docker compose -f ./digiur-net/docker/swing-music/docker-compose.yml up -d
    ColorReset

    Show 2 "Start transmission+gluetun..."
    GreyStart
    docker compose -f ./digiur-net/docker/transmission-plus-gluetun/docker-compose.yml up -d
    ColorReset

    Show 2 "Start uptime-kuma..."
    GreyStart
    docker compose -f ./digiur-net/docker/uptime-kuma/docker-compose.yml up -d
    ColorReset

    Show 0 "Digiur-net Setup complete."
}
