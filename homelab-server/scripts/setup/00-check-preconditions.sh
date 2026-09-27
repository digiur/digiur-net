#!/usr/bin/env bash
###############################################################################
# One-time/occasional: sanity-check host-specific storage and passthrough   #
# device paths. Read-only. Rerun any time storage or hardware changes       #
# (e.g. adding the NAS mount, a new drive, or an iGPU).                     #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"

REQUIRED_STORAGE_PATHS=(
    /storage
    /storage/media
    /storage/media/downloads
    /storage/media/downloads/raw
    /storage/tv
    /storage/movies
    /storage/roms
)

missing_paths=()
for path in "${REQUIRED_STORAGE_PATHS[@]}"; do
    [[ -d "$path" ]] || missing_paths+=("$path")
done

if (( ${#missing_paths[@]} > 0 )); then
    show 1 "Required storage paths are missing: ${missing_paths[*]}. Complete the README storage setup, then rerun."
fi
show 0 "All required storage paths present."

if [[ -e /dev/dri ]]; then
    show 0 "/dev/dri present. Jellyfin/HandBrake hardware acceleration available."
else
    show 3 "/dev/dri is missing. Jellyfin and HandBrake hardware acceleration will not be available."
fi

if [[ -e /dev/net/tun ]]; then
    show 0 "/dev/net/tun present. Gluetun and Tailscale can run."
else
    show 1 "/dev/net/tun is missing. Gluetun and Tailscale require it."
fi
