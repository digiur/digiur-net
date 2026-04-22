# Digiur Net

A lightweight(?) homelab stack for a mini-PC media server.

## Default Installed Services

The install script starts the services listed in:

- `scripts/services/active-services.txt`

Current default set:

- dashy
- handbrake
- jellyfin
- librespeed
- mealie
- myspeed
- portainer
- prowlarr
- qdirstat
- radarr
- romm
- sonarr
- transmission-plus-gluetun
- foundryvtt
- tailscale

Deprecated or experimental service stacks are kept under `docker/deprecated/` and are not part of the default install flow.

## Host Assumptions

- Ubuntu Server host.
- One OS drive (typically NVMe) and one larger media drive.
- Intel Quick Sync capable iGPU (for Jellyfin/HandBrake hardware acceleration).
- Docker and Docker Compose plugin installed by scripts.

## 1) OS Install

- Boot Ubuntu Server installer.
- Use LVM for the OS drive.
- Keep free space/headroom in the OS volume group for snapshot rollback points.
- Leave media drive available for ZFS pool creation.

## 2) Storage Setup (ZFS)

Install prerequisites:

```bash
sudo apt update
sudo apt install zfsutils-linux acl
```

Confirm target media drive:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

Create pool at `/storage`:

```bash
sudo zpool create \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=/storage \
  storage /dev/sda
```

Set storage permissions for containers (PUID/PGID 1000):

```bash
sudo chown -R 1000:1000 /storage
sudo chmod g+s /storage
sudo setfacl -m group:1000:rwx /storage
sudo setfacl -d -m group:1000:rwx /storage
sudo setfacl -d -m mask::rwx /storage
```

Create media folders:

```bash
mkdir -p /storage/media/downloads /storage/media/downloads/raw /storage/tv /storage/movies
```

## 3) Quick Setup

Run:

```bash
wget -qO- https://raw.githubusercontent.com/digiur/digiur-net/main/scripts/quickstart.sh | bash
```

What quickstart does:

- Clones this repository.
- Ensures your user is in the docker group.
- Copies these templates to `.env` files if missing:
  - `docker/transmission-plus-gluetun/.env.template`
  - `docker/foundryvtt/.env.template`
  - `docker/tailscale/.env.template`
- Prompts you to complete missing values for:
  - Transmission + Gluetun credentials
  - Foundry account credentials + admin key
  - Tailscale auth key + hostname
- Runs `scripts/install.sh`.

Plain `.env` files are local runtime secrets and are intentionally not tracked by git.

If docker group membership is newly added, log out/in once, then rerun:

```bash
./digiur-net/scripts/quickstart.sh
```

## 4) What Install Does

`scripts/install.sh` now:

- Resizes swap based on available disk/memory.
- Installs dependencies (including `inotify-tools`).
- Installs/verifies Docker.
- Validates Transmission/Gluetun, Foundry, and Tailscale env values.
- Generates Dashy config from `conf.yml.template` with host IP.
- Starts/updates default active services idempotently.
- Installs and starts `watch-gluetun-port.service` automatically.

## 5) Verify Transmission Port Watcher

Check service status:

```bash
sudo systemctl status watch-gluetun-port
```

Tail logs:

```bash
journalctl -f -u watch-gluetun-port
```

## 6) Optional Snapshot Rollback Workflow

Snapshots are for **rollback checkpoints**, not disaster recovery.

Use this policy:

- Before major change (OS package upgrades, docker image updates, script refactors), take a snapshot.
- If change succeeds, keep snapshot briefly, then prune old snapshots.
- Do not treat same-disk snapshots as backups.

Example root LV snapshot:

```bash
sudo lvs
sudo lvcreate --snapshot --size 20G --name pre-change-$(date +%Y%m%d) /dev/ubuntu-vg/ubuntu-lv
```

Restore is destructive and should be done only with explicit maintenance downtime.

## 7) FoundryVTT (Default Service)

Foundry is part of the default install and is started automatically.

Config files:

- `docker/foundryvtt/docker-compose.yml`
- `docker/foundryvtt/.env` (created from `.env.template` by quickstart if missing)

Required value:

- `FOUNDRY_USERNAME`
- `FOUNDRY_PASSWORD`
- `FOUNDRY_ADMIN_KEY`

Access:

- `http://<host-ip>:30000`

## 8) Tailscale Remote Access (Default Service)

Tailscale is part of the default install and is started automatically.

Config files:

- `docker/tailscale/docker-compose.yml`
- `docker/tailscale/.env` (created from `.env.template` by quickstart if missing)

Required value:

- `TS_AUTHKEY`
- `TS_HOSTNAME`

Goal:

- Keep app services LAN-only.
- Reach them remotely through VPN instead of exposing app ports directly to WAN.

## 9) First-Time App Configuration Notes

### Prowlarr

- Add indexers.
- Add Sonarr/Radarr under Settings -> Apps using host IP.
- Add Transmission under Download Clients.

### Sonarr

- Set root folder: `/storage/tv`.
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Radarr

- Set root folder: `/storage/movies`.
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Jellyfin

- Add libraries from `/storage`.

## 10) Useful Commands

Bring up a service:

```bash
docker compose -f docker/<service>/docker-compose.yml up -d
```

Check container status:

```bash
docker ps
```

View logs:

```bash
docker compose -f docker/<service>/docker-compose.yml logs -f
```
