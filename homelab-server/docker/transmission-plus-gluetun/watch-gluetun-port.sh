#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="/home/digiur/digiur-net/homelab-server/docker/transmission-plus-gluetun"
FORWARD_DIR="/opt/digiur-net/transmission-plus-gluetun/gluetun"
FORWARD_FILE="$FORWARD_DIR/forwarded_port"
ENV_FILE="$COMPOSE_DIR/.env"

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "Error: inotifywait is required. Install 'inotify-tools'."
  exit 1
fi

cd "$COMPOSE_DIR"

load_transmission_auth() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: missing env file $ENV_FILE"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$ENV_FILE"

  if [[ -z "${DESIRED_TRANSMISSION_USER:-}" || -z "${DESIRED_TRANSMISSION_PASS:-}" ]]; then
    echo "Error: transmission credentials are missing in $ENV_FILE"
    exit 1
  fi

  TRANSMISSION_AUTH="${DESIRED_TRANSMISSION_USER}:${DESIRED_TRANSMISSION_PASS}"
}

handle_port_change() {
  if [[ ! -f "$FORWARD_FILE" ]]; then
    echo "Warning: $FORWARD_FILE missing"
    return
  fi

  NEWPORT=$(< "$FORWARD_FILE")

  if [[ ! "$NEWPORT" =~ ^[0-9]+$ ]]; then
    echo "Warning: invalid forwarded port '$NEWPORT'"
    return
  fi

  echo "Detected new port: $NEWPORT"
  docker exec transmissionplus transmission-remote -n "$TRANSMISSION_AUTH" --port "$NEWPORT"
}

load_transmission_auth

echo "Watching $FORWARD_FILE for changes"

handle_port_change

inotifywait -m -e close_write "$FORWARD_DIR" | while read -r _ DIR FILENAME; do
  if [[ "$FILENAME" == "forwarded_port" ]]; then
    handle_port_change
  fi
done
