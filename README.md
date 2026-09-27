# Digiur Net

Monorepo for the infrastructure I run and maintain, split by environment:

- [`homelab-server/`](homelab-server/) — Docker Compose stack for the home media/services box (Jellyfin, arr stack, Mealie, etc.). See its [README](homelab-server/README.md) for install and service details.
- [`network-stack/`](network-stack/) — Home network device configuration (router/firewall, switch, VLANs).
- [`cloud-server/`](cloud-server/) — Files for the personal cloud/VPS server.

Each folder is meant to be self-contained: its own README/docs and its own `.gitignore` where ignore rules are needed, so nothing assumes the other folders exist.
