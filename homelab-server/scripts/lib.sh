#!/usr/bin/env bash
###############################################################################
# Shared helpers for deploy.sh and scripts/setup/*.sh                        #
###############################################################################
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$LIB_DIR/.." && pwd)"
readonly LOG_FILE="$REPO_ROOT/digiur-net.log"
readonly ACTIVE_SERVICES_FILE="$REPO_ROOT/scripts/services/active-services.txt"

readonly COLOUR_RESET='\e[0m'
readonly COLOUR_OK='\e[32m'
readonly COLOUR_FAIL='\e[31m'
readonly COLOUR_INFO='\e[34m'
readonly COLOUR_NOTICE='\e[33m'

# show <0=OK|1=FAIL|2=INFO|3=NOTICE> <message>
show() {
    local label colour
    case "$1" in
        0) label="OK"; colour="$COLOUR_OK" ;;
        1) label="FAILED"; colour="$COLOUR_FAIL" ;;
        2) label="INFO"; colour="$COLOUR_INFO" ;;
        3) label="NOTICE"; colour="$COLOUR_NOTICE" ;;
    esac
    echo -e "${colour}[${label}]${COLOUR_RESET} $2" | tee -a "$LOG_FILE"
    [[ "$1" == "1" ]] && exit 1
    return 0
}

show_time() {
    show 2 "$(date +"%Y-%m-%d %H:%M:%S")"
}

###############################################################################
# Env file helpers                                                           #
###############################################################################
Ensure_Env_File_From_Template() {
    local env_file="$1"
    local env_template="$2"

    [[ -f "$env_file" ]] && return
    [[ -f "$env_template" ]] || show 1 "Template '$env_template' not found for '$env_file'."

    cp "$env_template" "$env_file"
    show 0 "Created '$env_file' from template."
}

Get_Env_Value() {
    local env_file="$1"
    local key="$2"
    local line

    [[ -f "$env_file" ]] || return
    line=$(grep -E "^${key}=" "$env_file" | tail -n 1 || true)
    [[ -n "$line" ]] && printf '%s' "${line#*=}"
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

    [[ -z "$(Get_Env_Value "$env_file" "$key")" ]] && Set_Env_Value "$env_file" "$key" "$value"
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
    [[ -z "$raw_name" ]] && raw_name="digiur-net"
    printf '%s' "$raw_name"
}

###############################################################################
# Per-service env defaults/requirements                                      #
# Add an entry here whenever a service needs a generated default or a       #
# manually-supplied secret validated before it can start.                   #
###############################################################################
declare -gA SERVICE_REQUIRED_VARS=(
    [transmission-plus-gluetun]="PROTON_VPN_USER PROTON_VPN_PASS DESIRED_TRANSMISSION_PASS"
    [foundryvtt]="FOUNDRY_USERNAME FOUNDRY_PASSWORD"
    [tailscale]="TS_AUTHKEY"
    [romm]="IGDB_CLIENT_ID IGDB_CLIENT_SECRET"
)

# Apply safe, non-secret defaults (host IP, generated passwords/keys).
Apply_Generated_Env_Defaults() {
    local svc="$1"
    local env_file="$REPO_ROOT/docker/$svc/.env"

    case "$svc" in
        mealie)
            Set_Env_Value "$env_file" MEALIE_BASE_URL "http://$(Get_Host_IP):9925"
            ;;
        transmission-plus-gluetun)
            Set_Env_Value "$env_file" DESIRED_TRANSMISSION_USER "transmission"
            ;;
        foundryvtt)
            Ensure_Env_Value "$env_file" FOUNDRY_ADMIN_KEY "$(Generate_Random_Hex 64)"
            ;;
        tailscale)
            Ensure_Env_Value "$env_file" TS_HOSTNAME "$(Get_Default_Tailscale_Hostname)"
            ;;
        librespeed)
            Ensure_Env_Value "$env_file" LIBRESPEED_PASSWORD "$(Generate_Random_Alnum 24)"
            ;;
        romm)
            Ensure_Env_Value "$env_file" ROMM_AUTH_SECRET_KEY "$(Generate_Random_Hex 64)"
            Ensure_Env_Value "$env_file" ROMM_DB_PASSWORD "$(Generate_Random_Alnum 24)"
            Ensure_Env_Value "$env_file" ROMM_DB_ROOT_PASSWORD "$(Generate_Random_Alnum 24)"
            ;;
    esac
}

Validate_Service_Required_Vars() {
    local svc="$1"
    local env_file="$REPO_ROOT/docker/$svc/.env"
    local required_vars=(${SERVICE_REQUIRED_VARS[$svc]:-})
    local missing=()
    local var_name

    [[ ${#required_vars[@]} -eq 0 ]] && return

    [[ -f "$env_file" ]] || show 1 "Required env file '$env_file' not found for '$svc'."

    # shellcheck disable=SC1090
    source "$env_file"

    for var_name in "${required_vars[@]}"; do
        [[ -z "${!var_name:-}" ]] && missing+=("$var_name")
    done

    if (( ${#missing[@]} > 0 )); then
        show 1 "'$svc' is missing required values in '$env_file': ${missing[*]}. Edit the file, then rerun deploy.sh."
    fi

    show 0 "'$svc' credentials look good."
}

# Copy .env.template -> .env (if present and missing), apply generated
# defaults, and fail fast if manually-supplied secrets are still missing.
Prepare_Service_Env() {
    local svc="$1"
    local dir="$REPO_ROOT/docker/$svc"
    local template="$dir/.env.template"

    [[ -f "$template" ]] && Ensure_Env_File_From_Template "$dir/.env" "$template"

    Apply_Generated_Env_Defaults "$svc"
    Validate_Service_Required_Vars "$svc"
}

###############################################################################
# Compose helpers                                                            #
###############################################################################
Compose_With_Service_Env() {
    local compose_file="$1"
    shift

    local service_dir service_env_file
    local compose_cmd=(docker compose)

    service_dir="$(dirname "$compose_file")"
    service_env_file="$service_dir/.env"

    [[ -f "$service_env_file" ]] && compose_cmd+=(--env-file "$service_env_file")

    compose_cmd+=(-f "$compose_file" "$@")
    "${compose_cmd[@]}"
}

Validate_Service_Compose() {
    local svc="$1"
    local compose_file="$2"

    show 2 "Validating compose config for '$svc'..."
    Compose_With_Service_Env "$compose_file" config >/dev/null
}

Check_Service_Runtime_Status() {
    local svc="$1"
    local compose_file="$2"
    local ps_output

    ps_output=$(Compose_With_Service_Env "$compose_file" ps --format json 2>/dev/null || true)

    if [[ -z "$ps_output" ]]; then
        show 3 "Unable to determine runtime status for '$svc'. Check manually with 'cd docker/$svc; docker compose ps'."
        return
    fi

    if printf '%s' "$ps_output" | grep -qi '"State":"running"'; then
        show 0 "'$svc' has running containers."
    else
        show 3 "'$svc' has no running containers. Check with 'cd docker/$svc; docker compose ps' and inspect logs."
    fi
}

Deploy_Service() {
    local svc="$1"
    local compose_file="$REPO_ROOT/docker/$svc/docker-compose.yml"

    [[ -f "$compose_file" ]] || show 1 "Compose file missing for '$svc': $compose_file"

    Validate_Service_Compose "$svc" "$compose_file"

    show 2 "Deploying '$svc'..."
    Compose_With_Service_Env "$compose_file" up -d
    Check_Service_Runtime_Status "$svc" "$compose_file"
}

Load_Active_Services() {
    [[ -f "$ACTIVE_SERVICES_FILE" ]] || show 1 "Active services file '$ACTIVE_SERVICES_FILE' not found."

    mapfile -t ACTIVE_SERVICES < <(grep -Ev '^\s*(#|$)' "$ACTIVE_SERVICES_FILE")

    (( ${#ACTIVE_SERVICES[@]} == 0 )) && show 1 "No active services listed in '$ACTIVE_SERVICES_FILE'."
}

Is_Service_Active() {
    local svc="$1"
    local s
    for s in "${ACTIVE_SERVICES[@]}"; do
        [[ "$s" == "$svc" ]] && return 0
    done
    return 1
}

Handle_Dashy_IP_Config_If_Active() {
    Is_Service_Active dashy || return 0

    local host_ip dashy_template dashy_conf
    host_ip=$(Get_Host_IP)
    dashy_template="$REPO_ROOT/docker/dashy/app/user-data/conf.yml.template"
    dashy_conf="$REPO_ROOT/docker/dashy/app/user-data/conf.yml"

    [[ -f "$dashy_template" ]] || show 1 "Template file $dashy_template not found"
    [[ -f "$dashy_conf" ]] || cp "$dashy_template" "$dashy_conf"

    if grep -q '{{HOST_IP}}' "$dashy_conf"; then
        sed -i "s|{{HOST_IP}}|$host_ip|g" "$dashy_conf"
        show 0 "Dashy conf generated with host IP: $host_ip"
    fi
}
