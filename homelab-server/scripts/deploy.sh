#!/usr/bin/env bash
###############################################################################
# Day-2 deploy: prepare env files, then bring up all active services.       #
# Safe to rerun any time — does not touch host-level config (see            #
# scripts/setup/ for one-time/occasional host setup steps).                 #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

cd "$REPO_ROOT"

show_time
show 2 "*** digiur-net deploy start ***"

Load_Active_Services
show 2 "Active services: ${ACTIVE_SERVICES[*]}"

for svc in "${ACTIVE_SERVICES[@]}"; do
    Prepare_Service_Env "$svc"
done

Handle_Dashy_IP_Config_If_Active

for svc in "${ACTIVE_SERVICES[@]}"; do
    Deploy_Service "$svc"
done

show 2 "*** digiur-net deploy complete ***"
show_time
