# Digiur Net

A lightweight(?) homelab stack for a mini-PC media server.

## Default Installed Services

The deploy script starts the services listed in:

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
- One OS drive (typically NVMe) and one local drive (1TB) for the download/processing pipeline — the served media library lives on the NAS instead.
- Intel Quick Sync capable iGPU (for Jellyfin/HandBrake hardware acceleration).
- Docker and Docker Compose plugin installed manually (see "One-Time Host Setup" below).

## 1) OS Install

- Boot Ubuntu Server installer.
- When prompted for storage: select the NVMe drive as the boot device and the mount point for `/` (root filesystem).
- Use **ext4** as the filesystem.
- Do **not** create or configure anything on the 1TB drive — leave it untouched.

## 2) Storage Setup (ext4)

The 1TB drive only holds the download/processing pipeline now (transient, reacquirable data) — the served library lives on the NAS. Nothing here needs ZFS's compression, checksums, or snapshots, so plain ext4 keeps this simpler with one fewer subsystem to maintain. `noatime` and `acl` mount options give you the same practical wins (skip access-time writes, POSIX ACL support for Docker's PUID/PGID 1000) without the extra tooling.

Install prerequisites:

```bash
sudo apt update
sudo apt install acl
```

- `acl` — POSIX access control list tools (`setfacl`/`getfacl`), needed for granular permissions on the drive

Confirm target drive:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

Lists all block devices. Find the 1TB drive (should be `/dev/sda`). Confirm it shows **no partitions or filesystems** — it's untouched from the installer.

Partition and format:

```bash
sudo parted /dev/sda --script mklabel gpt mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/sda1
```

- **`parted ... mklabel gpt mkpart primary ext4 0% 100%`** — creates a GPT partition table with a single partition spanning the whole drive. **Adjust `/dev/sda` if your drive is `/dev/sdb`, `/dev/nvme1n1`, etc.**
- **`mkfs.ext4 /dev/sda1`** — formats that partition as ext4.

Mount at `/storage`:

```bash
sudo mkdir -p /storage
sudo blkid /dev/sda1
```

`blkid` prints the partition's UUID — copy it for the next step. Using UUID instead of `/dev/sda1` in `/etc/fstab` keeps the mount stable even if drive letters shift (e.g. after adding another drive).

Add to `/etc/fstab` (replace `<uuid>` with the value from `blkid` above):

```
UUID=<uuid>  /storage  ext4  defaults,noatime,acl  0  2
```

- **`noatime`** — don't update "last access time" on reads (saves I/O; Jellyfin/RomM don't care).
- **`acl`** — enables POSIX ACL support (needed for the `setfacl` commands below; compatible with Docker).

```bash
sudo mount -a
df -h /storage
```

Confirms the mount succeeded and shows available space.

Set storage permissions for containers (PUID/PGID 1000):

```bash
sudo chown -R 1000:1000 /storage
```

Change owner and group of `/storage` to UID/GID 1000 (the user inside Docker containers). Docker containers run as user 1000 by default in the compose files; they need to read/write here.

```bash
sudo chmod g+s /storage
```

Set the setgid bit on the directory. All *new* files created under `/storage` inherit the parent directory's group (1000), not the creating process's group. Keeps permissions consistent.

```bash
sudo setfacl -m group:1000:rwx /storage
```

Grant group 1000 full read-write-execute (rwx) on the `/storage` directory itself.

```bash
sudo setfacl -d -m group:1000:rwx /storage
sudo setfacl -d -m mask::rwx /storage
```

Set default ACLs so **new files/subdirectories** automatically inherit group 1000 permissions. The `mask::rwx` keeps the effective permission wide open (no restrictive umask).

Verify permissions are set correctly:

```bash
sudo ls -ldn /storage
sudo getfacl /storage
```

Should show owner/group as `1000 1000` and ACLs with `group:1000:rwx`.

Create local pipeline folders (single ext4 filesystem — required so Sonarr/Radarr's hardlink import is free instead of a full copy):

```bash
mkdir -p /storage/downloads/raw /storage/downloads/processing/tv /storage/downloads/processing/movies
```

Creates the three directories Transmission, Sonarr/Radarr, and HandBrake will use. The `-p` flag creates parent directories if missing. All inherit the permissions set above, so containers can read/write immediately.

### NAS Share Setup (WD MyCloud EX2 Ultra)

Do this once, on the NAS itself, to prepare the share for mounting from the server.

**Use the built-in `Public` share** — WD MyCloud units ship with an undeletable default share named `Public`. There's no need to create a separate `media` share; the share's name on the NAS has no bearing on the mount point name used on the server (`/mnt/nas` below).

**One share, not three.** `tv`, `movies`, and `roms` are subfolders of that single share, matching the single `/mnt/nas` mount used below — three separate shares would mean three separate NFS exports and three `/etc/fstab` lines for no real benefit here.

1. Log into the NAS dashboard (`http://10.0.20.20`).
2. **Enable NFS globally**: Settings -> Network -> Network Services -> NFS: On. (Exact menu wording varies by firmware version.)
3. **Enable protocols on `Public`**: Storage -> Shares -> `Public` -> enable **SMB** (so Windows clients can browse it) and **NFS** (so the server can mount it).
   - Leave **Host** set to `*` (any host) and **Write** turned ON for now. You'll restrict these after creating the folders from the server.
   - Access: **Public** shares have no auth by default, which is what we want here — this NAS is LAN-only and already sits behind the VLAN firewall (see `network-stack/`), and WD's NFS implementation doesn't do real per-user permission mapping anyway, so an authenticated share mostly adds friction without adding real security.
4. Storage -> Shares -> `Public` -> NFS settings:
   - **Host**: change from `*` (any host) to the server's static IP/reservation (e.g. `10.0.20.10`). This is a second, independent layer on top of the VLAN firewall rules that already scope which devices can reach the NAS at all.
   - **Write**: leave **ON** (required — HandBrake needs to write finished transcodes here).

Confirm the share is still accessible from Windows and the server:

- From Windows: browse to `\\10.0.20.20\Public` in File Explorer.

### NAS Mount (NFS)

The served media library and ROM library live on the NAS (WD MyCloud EX2 Ultra), not on local storage — only the download/processing pipeline is local. Mount the NAS over NFS so HandBrake can write finished transcodes there and Jellyfin/RomM can read from it:

```bash
sudo apt install nfs-common
showmount -e 10.0.20.20
sudo mkdir -p /mnt/nas
sudo nano /etc/fstab
```

Add to `/etc/fstab` (replace with the actual export path from `showmount -e 10.0.20.20`):

```
10.0.20.20:/mnt/HD/HD_a2/Public  /mnt/nas  nfs  defaults,_netdev,noatime  0  0
```

Mount and verify the export is reachable:

```bash
sudo systemctl daemon-reload
sudo mount -a
df -h /mnt/nas
```

Remove the existing (default) shared folders from the NAS export if they exist.
Create the three library folders via the NFS mount:

```bash
rm -rf '/mnt/nas/Shared Music' '/mnt/nas/Shared Pictures' '/mnt/nas/Shared Videos'
mkdir -p /mnt/nas/tv /mnt/nas/movies /mnt/nas/roms
```

These are created on the server side through the NFS mount, which requires write permissions.

## 3) One-Time Host Setup

These are manual steps, done once on a fresh host (or individually re-done any time the thing they cover changes — new drive, moved repo, etc). They depend on the physical machine, so they're documentation, not scripts.

### Verify preconditions

```bash
ls -d /storage /storage/downloads/raw /storage/downloads/processing/tv /storage/downloads/processing/movies
ls -d /mnt/nas/tv /mnt/nas/movies /mnt/nas/roms
ls /dev/dri     # optional — needed for Jellyfin/HandBrake hardware acceleration
ls /dev/net/tun # required — needed for Gluetun and Tailscale
```

### Install dependencies

```bash
sudo apt update
sudo apt install -y btop curl ca-certificates inotify-tools
```

### Install Docker

Follow the [Install using the `apt` repository](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) steps, then run:

```bash
sudo usermod -aG docker $USER
# log out and back in for the group change to apply
```

Adds your user to the `docker` group so you can run `docker`/`docker compose` without `sudo`.

### Swap size (optional)

Rarely needed again after initial setup. See: https://help.ubuntu.com/community/SwapFaq

```bash
swapon --show
# example: resize an existing swapfile at /swap.img to 8G
sudo swapoff /swap.img
sudo dd if=/dev/zero of=/swap.img bs=1G count=8 status=progress
sudo mkswap /swap.img
sudo swapon /swap.img
```

## 4) Get the Repo

```bash
git clone https://github.com/digiur/digiur-net.git
cd digiur-net/homelab-server
```

If it's already cloned, just pull the latest changes instead:

```bash
git pull
```

## 5) Deploy Services

Deploying each service manually, one at a time — starting with Dashy, then the services that need little to no configuration, then the ones needing minor in-app setup, then the ones needing manually-supplied secrets. Verify each before moving to the next.

First, note your host's LAN IP — several steps below need it:

```bash
hostname -I
```

### Dashy (dashboard)

Deploy first, since it links out to every other service:

```bash
cd docker/dashy
cp app/user-data/conf.yml.template app/user-data/conf.yml
sed -i "s|{{HOST_IP}}|<host-ip>|g" app/user-data/conf.yml
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>` should return `200 OK`.

### No-Config Services

These start with nothing to configure.

**Portainer** — Docker management UI:

```bash
cd docker/portainer && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:9000`

**qdirstat** — disk usage viewer:

```bash
cd docker/qdirstat && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:3000`

**myspeed** — speed test history:

```bash
cd docker/myspeed && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:5216`

**Jellyfin** — media server (GPU passthrough already confirmed via `/dev/dri` earlier):

```bash
cd docker/jellyfin && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:8096`. Add libraries once the NAS has media — see section 12.

**HandBrake** — auto-transcode watcher (GPU passthrough already confirmed):

```bash
cd docker/handbrake && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:5800`. Nothing to transcode yet until Sonarr/Radarr/Transmission are feeding it files.

### Services With Minor Setup

No manually-supplied secrets, but need a generated value or later in-app configuration.

**Mealie** — needs its base URL:

```bash
cd docker/mealie
echo "MEALIE_BASE_URL=http://<host-ip>:9925" > .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:9925`

**Librespeed** — needs a login password:

```bash
cd docker/librespeed
echo "LIBRESPEED_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)" > .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:81`. Password is in `docker/librespeed/.env` if you need it later.

**Prowlarr, Sonarr, Radarr** — no secrets, but need in-app configuration (indexers, root folders, download client) once all three plus Transmission are up — see section 12:

```bash
cd docker/prowlarr && docker compose up -d && cd ../..
cd docker/sonarr && docker compose up -d && cd ../..
cd docker/radarr && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:9696`, `:8989`, `:7878`.

### Services Needing Secrets

These need real credentials before they'll start successfully — most config, deploy last.

**Transmission + Gluetun**:

```bash
cd docker/transmission-plus-gluetun
cp .env.template .env
nano .env   # fill in DESIRED_TRANSMISSION_PASS, PROTON_VPN_USER, PROTON_VPN_PASS
echo "DESIRED_TRANSMISSION_USER=transmission" >> .env
docker compose up -d
cd ../..
```

Verify: `docker compose ps` shows both containers running, then `curl -I http://<host-ip>:9091` (Transmission web UI, proxied through Gluetun).

**FoundryVTT** — see section 9 for required values:

```bash
cd docker/foundryvtt
cp .env.template .env
nano .env   # fill in FOUNDRY_USERNAME, FOUNDRY_PASSWORD
echo "FOUNDRY_ADMIN_KEY=$(openssl rand -hex 32)" >> .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:30000`

**Tailscale** — see section 10 for required values:

```bash
cd docker/tailscale
cp .env.template .env
nano .env   # fill in TS_AUTHKEY
echo "TS_HOSTNAME=$(hostname | tr '[:upper:]' '[:lower:]')" >> .env
docker compose up -d
cd ../..
```

Verify: `docker exec tailscale tailscale status`

**RomM** — see section 11 for required values:

```bash
cd docker/romm
cp .env.template .env
nano .env   # fill in IGDB_CLIENT_ID, IGDB_CLIENT_SECRET
echo "ROMM_AUTH_SECRET_KEY=$(openssl rand -hex 32)" >> .env
echo "ROMM_DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)" >> .env
echo "ROMM_DB_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)" >> .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:1337`

Plain `.env` files are local runtime config/secrets and are intentionally not tracked by git.

Once every service above is verified working, `scripts/deploy.sh` automates this same flow (env prep + generated defaults + `docker compose up -d` for every active service) for repeatable day-2 deploys.

## 6) Gluetun Port Watcher (only if running transmission-plus-gluetun)

Run once the stack is up. Run from the `homelab-server` directory so `$(pwd)` resolves correctly. Rerun this if the repo is ever moved.

```bash
sudo sed \
  -e "s|__INSTALL_USER__|$USER|g" \
  -e "s|__REPO_ROOT__|$(pwd)|g" \
  scripts/services/watch-gluetun-port.service | sudo tee /etc/systemd/system/watch-gluetun-port.service >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now watch-gluetun-port
```

Check service status:

```bash
sudo systemctl status watch-gluetun-port
```

Tail logs:

```bash
journalctl -f -u watch-gluetun-port
```

## 7) Smoke Checks

Run these any time after storage setup and service deployment to double-check everything is healthy.

### Storage / ext4

Confirm the drive is mounted and has space:

```bash
df -h /storage
mount | grep /storage
```

### Docker / Compose

Confirm the default stack is running:

```bash
docker ps
```

Validate a service compose file resolves correctly:

```bash
cd docker/transmission-plus-gluetun
docker compose config >/dev/null
```

### Dashy / App Reachability

Check that the main web UIs are answering on the host:

```bash
curl -I http://<host-ip>
curl -I http://<host-ip>:8096
curl -I http://<host-ip>:9925
curl -I http://<host-ip>:1337
curl -I http://<host-ip>:30000
```

### Transmission + Gluetun

Confirm both containers are up and Transmission responds:

```bash
cd docker/transmission-plus-gluetun
docker compose ps
docker logs gluetun --tail 50
docker exec transmissionplus transmission-remote -n "transmission:<your-password>" --session-info
```

### Tailscale

Confirm the node joined the tailnet:

```bash
cd docker/tailscale
docker compose ps
docker logs tailscale --tail 50
docker exec tailscale tailscale status
```

### RomM

Confirm both the app and database are healthy enough to stay running:

```bash
cd docker/romm
docker compose ps
docker logs romm --tail 50
docker logs romm-db --tail 50
```

## 8) Rollback Strategy

With ext4 on the OS drive, you don't have snapshots. That's fine — the homelab stack is intentionally stateless (config and data live elsewhere). If OS-level changes break something:

- Docker containers are replaceable.
- `/storage` and `/mnt/nas` are independent.
- Worst case: reinstall the OS from scratch (takes 15 minutes).

If you want a safety net before major changes (kernel updates, Docker upgrades), use `dd` or `pv` to image the NVMe to a USB stick beforehand — clunky but effective.

## 9) FoundryVTT (Default Service)

Foundry is part of the default install and is started automatically.

Config files:

- `docker/foundryvtt/docker-compose.yml`
- `docker/foundryvtt/.env` (created from `.env.template` by deploy.sh if missing)

Required value:

- `FOUNDRY_USERNAME`
- `FOUNDRY_PASSWORD`

Generated by deploy.sh:

- `FOUNDRY_ADMIN_KEY`

Access:

- `http://<host-ip>:30000`

## 10) Tailscale Remote Access (Default Service)

Tailscale is part of the default install and is started automatically.

Config files:

- `docker/tailscale/docker-compose.yml`
- `docker/tailscale/.env` (created from `.env.template` by deploy.sh if missing)

Required value:

- `TS_AUTHKEY`

Generated by deploy.sh:

- `TS_HOSTNAME`

Goal:

- Keep app services LAN-only.
- Reach them remotely through VPN instead of exposing app ports directly to WAN.

## 11) RomM (Default Service)

RomM is part of the default install and is started automatically.

Config files:

- `docker/romm/docker-compose.yml`
- `docker/romm/.env` (created from `.env.template` by deploy.sh if missing)

Required value:

- `IGDB_CLIENT_ID`
- `IGDB_CLIENT_SECRET`

Generated by deploy.sh:

- `ROMM_AUTH_SECRET_KEY`
- `ROMM_DB_PASSWORD`
- `ROMM_DB_ROOT_PASSWORD`

Default library path:

- `/mnt/nas/roms`

## 12) First-Time App Configuration Notes

### Prowlarr

- Add indexers.
- Add Sonarr/Radarr under Settings -> Apps using host IP.
- Add Transmission under Download Clients.

### Sonarr

- Set root folder: `/storage/downloads/processing/tv` (Sonarr renames/hardlinks here; HandBrake watches this path and writes the finished transcode to `/mnt/nas/tv`).
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Radarr

- Set root folder: `/storage/downloads/processing/movies` (same pattern — HandBrake writes the finished transcode to `/mnt/nas/movies`).
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Jellyfin

- Add libraries from `/mnt/nas/tv` and `/mnt/nas/movies`.

## 13) Useful Commands

Bring up a service:

```bash
cd docker/<service>
docker compose up -d
```

Check container status:

```bash
docker ps
```

View logs:

```bash
cd docker/<service>
docker compose logs -f
```
