#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$HOME/digiur-net/docker/transmission-plus-gluetun"
FORWARD_FILE="$COMPOSE_DIR/gluetun/forwarded_port"
ENV_FILE="$COMPOSE_DIR/transmission.env"

cd "$COMPOSE_DIR"

echo "Gluetun port watcher started, waiting for changes..."

inotifywait -m -e close_write "$FORWARD_FILE" | while read -r _events filename; do
  NEWPORT="$(< "$FORWARD_FILE")"
  echo "$(date +'%F %T')  Detected new port: $NEWPORT"

  # 1) update env file (optional technically but probs best)
  echo "PEERPORT=$NEWPORT" > "$ENV_FILE"

  # 2) patch Transmission's settings.json
  CONFIG_DIR="$COMPOSE_DIR/transmission/config"
  SETTINGS="$CONFIG_DIR/settings.json"
  sed -i -E "s/\"peer-port\"\s*:\s*[0-9]+/\"peer-port\": $NEWPORT/" "$SETTINGS"

  # 3) restart Transmission
  docker compose up -d --no-deps --force-recreate transmissionplus
done
