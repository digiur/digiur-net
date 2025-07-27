#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$HOME/digiur-net/docker/transmission-plus-gluetun"
FORWARD_DIR="$COMPOSE_DIR/gluetun"
FORWARD_FILE="$FORWARD_DIR/forwarded_port"
ENV_FILE="$COMPOSE_DIR/transmission.env"
TRANSMISSION_SETTINGS="$COMPOSE_DIR/transmission/config/settings.json"

cd "$COMPOSE_DIR"

handle_port_change() {
  if [[ ! -f "$FORWARD_FILE" ]]; then
    echo "Warning: $FORWARD_FILE missing"
    return
  fi
  NEWPORT=$(< "$FORWARD_FILE")
  echo "Detected new port: $NEWPORT"
  echo "PEERPORT=$NEWPORT" > "$ENV_FILE"
  # sed -i -E "s/\"peer-port\"\s*:\s*[0-9]+/\"peer-port\": $NEWPORT/" "$TRANSMISSION_SETTINGS"
  docker compose up -d --no-deps --force-recreate transmissionplus
}

echo "Watching $FORWARD_FILE for changes…"

# Watch the *directory* for the forwarded_port file being created/moved
inotifywait -m -e moved_to -e create "$FORWARD_DIR" | while read -r _ DIR FILENAME; do
  if [[ "$FILENAME" == "forwarded_port" ]]; then
    handle_port_change
  fi
done
