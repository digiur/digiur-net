#!/usr/bin/env bash
###############################################################################
# One-time/occasional: size swap based on current disk/memory. Depends on  #
# physical disk layout — rerun manually if storage or RAM changes.         #
# See: https://help.ubuntu.com/community/SwapFaq                           #
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib.sh"

PHYSICAL_MEMORY_GB=$(LC_ALL=C free --giga | awk '/Mem:/ { print $2 }')
FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

SWAP_FILE=$(LC_ALL=C swapon --show | tail -n 1 | awk '{print $1}')
SWAP_FILE_BYTES=$(LC_ALL=C stat -c %s "$SWAP_FILE")
SWAP_FILE_GB=$((SWAP_FILE_BYTES / 1024 / 1024))

TARGET_SWAP_BY_DISK=$((FREE_DISK_GB / 4))

# Use the smaller of memory-based and disk-based targets.
if (( PHYSICAL_MEMORY_GB < TARGET_SWAP_BY_DISK )); then
    TARGET_SWAP_GB=$PHYSICAL_MEMORY_GB
else
    TARGET_SWAP_GB=$TARGET_SWAP_BY_DISK
fi

if (( SWAP_FILE_GB >= TARGET_SWAP_GB )); then
    show 0 "Swap file is already ${SWAP_FILE_GB}GB, which is >= target ${TARGET_SWAP_GB}GB. Skipping resize."
    exit 0
fi

show 2 "Turning off swap..."
sudo swapoff "$SWAP_FILE"

show 2 "Resizing swap to ${TARGET_SWAP_GB}GB in-place..."
sudo dd if=/dev/zero of="$SWAP_FILE" count="$TARGET_SWAP_GB" bs=1G status=progress

show 2 "Creating new swap space on $SWAP_FILE..."
sudo mkswap "$SWAP_FILE"
sudo chmod 0600 "$SWAP_FILE"

show 2 "Turning on swap..."
sudo swapon "$SWAP_FILE"
sudo swapon --show

show 0 "Swap resized to ${TARGET_SWAP_GB}GB."
