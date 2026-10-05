# Digiur Net

A lightweight(?) homelab stack for a mini-PC media server.

## Service Stacks

Start service stacks manually with `docker compose up -d` from each stack's directory, following the setup below.

Active service stacks:

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
- cloudflared
- pihole (optional)

Deprecated or experimental service stacks are kept under `deprecated/` and are not part of the active service setup.

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

### App data directory

All service configs and databases live under `/opt/digiur-net`, independent of this repo checkout — re-cloning or wiping the repo never touches running app data.

```bash
sudo mkdir -p /opt/digiur-net
sudo chown 1000:1000 /opt/digiur-net
sudo chmod g+s /opt/digiur-net
sudo setfacl -m group:1000:rwx /opt/digiur-net
sudo setfacl -d -m group:1000:rwx /opt/digiur-net
sudo setfacl -d -m mask::rwx /opt/digiur-net
```

Same pattern as the `/storage` setup above: the setgid bit and default ACLs mean any subdirectory created later — whether by you running `mkdir`, or by Docker auto-creating a missing bind-mount path — automatically gets group `1000` with read/write/execute, regardless of who created it. No need to pre-create or `chown` each service's subdirectory individually; just deploy each service one at a time and let Docker create its own path under `/opt/digiur-net/<service>/...` on first `docker compose up -d`.

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

### Pi-hole DNS port (optional)

The Pi-hole stack uses host networking so its query log can identify clients by their real IP addresses. It therefore needs to bind DNS port 53 directly on the host. Ubuntu's `systemd-resolved` stub listener commonly occupies that port. If you plan to run Pi-hole, disable only the stub listener and point `/etc/resolv.conf` at systemd-resolved's upstream list; keep `systemd-resolved` running:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/no-stub.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
resolvectl query example.com
```

Actually check who answers DNS queries for the host:

```bash
cat /etc/resolv.conf
getent ahosts example.com
```

Confirm the host can still resolve names before starting Pi-hole. Do not configure the host to use Pi-hole itself as its only resolver; Docker needs working DNS to recreate Pi-hole if it is stopped.

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
mkdir -p /opt/digiur-net/dashy/user-data
cp docker/dashy/app/user-data/conf.yml.template /opt/digiur-net/dashy/user-data/conf.yml
sed -i "s|{{HOST_IP}}|10.0.20.10|g" /opt/digiur-net/dashy/user-data/conf.yml
cd docker/dashy
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

**myspeed** — speed test history:

```bash
cd docker/myspeed && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:5216`

**HandBrake** — manual transcoding via its web GUI (GPU passthrough already confirmed). Automated watch-folder conversion is disabled (`AUTOMATED_CONVERSION: 0`); browse and convert files yourself through the GUI, reading from the read-only `/storage` mount and saving to `/output` (`/mnt/nas`):

```bash
cd docker/handbrake && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:5800`.

Note: HandBrake's automated converter is a blind preset-apply with no library awareness. If you outgrow manual conversion, [Tdarr](https://docs.tdarr.io/) (library-aware, plugin-based, skips already-optimized files) or [Unmanic](https://docs.unmanic.app/) (lighter-weight equivalent) are purpose-built alternatives worth a look before automating this again.

### Pi-hole DNS (optional)

Pi-hole uses host networking so its query log records real client IPs. Keep the N100's host resolver pointed at OPNsense (`10.0.20.1`); Pi-hole also forwards to that Unbound resolver. Use the N100's reserved VLAN 20 address as `<pihole-ip>` below.

Start and test Pi-hole directly before changing Docker's DNS or any DHCP scopes:

```bash
cd docker/pihole
cp .env.template .env
openssl rand -base64 24
nano .env   # set PIHOLE_WEBPASSWORD to the generated value
docker compose config --quiet
docker compose up -d
docker compose ps
nslookup example.com <pihole-ip>
```

The password must be non-empty; a blank Pi-hole v6 web API password disables web authentication. The web UI is at `http://<host-ip>:8053/admin/`.

#### Pi-hole web UI

Log in with the password in `docker/pihole/.env`. Compose configures the web port, listening mode, and Unbound upstream (`10.0.20.1`); these environment-backed settings are read-only in Pi-hole and should be changed in Compose instead. DNS query logging is enabled by default, so no extra UI setup is needed for the Query Log.

For this setup, Unbound remains the only DNS blocking layer. Pi-hole's own blocking is disabled in Compose, so do not add the Unbound blocklists again under Pi-hole's **Lists** page. Use **Query Log** to inspect client queries once clients or Docker containers are using Pi-hole. If the filtering design changes later, Pi-hole lists are managed separately in the web UI and must be applied with **Update Gravity**.

Configure Docker's default DNS so bridge-network containers use Pi-hole. Edit `/etc/docker/daemon.json`, preserving any existing settings and merging in this property with the N100's reserved IP:

```json
{
   "dns": ["<pihole-ip>"]
}
```

Validate the configuration, then restart Docker:

```bash
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
```

The restart briefly interrupts containers; Pi-hole's `unless-stopped` policy should bring it back. Wait for Pi-hole to answer a DNS query before continuing. Then recreate each existing bridge-network Compose stack so its containers receive the new DNS setting:

```bash
cd docker/<service>
docker compose up -d --force-recreate
```

Do not add OPNsense as a second Docker DNS server if you want container queries to consistently pass through Pi-hole; Docker/application resolver behavior does not guarantee a strict primary/fallback order. If Pi-hole is unavailable, containers may temporarily lose DNS, but the host remains able to resolve names through OPNsense and restart the Pi-hole stack. Host-network containers continue using the host's resolver; Pi-hole's own forwarding is explicitly configured to OPNsense.

Finally, allow each client VLAN that should use Pi-hole to reach `<pihole-ip>` on TCP/UDP port 53, with the pass rule above that VLAN's private-range block. Change DHCP option 6 on one test VLAN to `<pihole-ip>`, renew a client lease, and verify DNS before applying the change to other VLANs. To roll back, restore that scope's prior DNS option (OPNsense's interface address) and renew the test client's lease.

### Services With Minor Setup

No manually-supplied secrets, but need a generated value or later in-app configuration.

**Mealie** — needs its base URL:

```bash
cd docker/mealie
cp .env.template .env
nano .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:9925`

**Librespeed** — needs a login password:

```bash
cd docker/librespeed
cp .env.template .env
nano .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:81`. Password is in `docker/librespeed/.env` if you need it later.

**qdirstat** — disk usage viewer with full read-only access to the host filesystem. As of the 2025 Selkies rebase it's a full streamed desktop requiring HTTPS, so it needs a login:

```bash
cd docker/qdirstat
cp .env.template .env
nano .env
docker compose up -d
cd ../..
```

Verify: `curl -Ik https://<host-ip>:3001` (self-signed cert, hence `-k`). Log in with user `admin` and the password from `docker/qdirstat/.env`.

**Jellyfin** — media server (GPU passthrough already confirmed via `/dev/dri` earlier):

```bash
cd docker/jellyfin
cp .env.template .env
nano .env
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:8096`. Add libraries once the NAS has media — see section 13.

**Prowlarr, Sonarr, Radarr** — no secrets, but need in-app configuration (indexers, root folders, download client) once all three plus Transmission are up — see section 13:

```bash
cd docker/prowlarr && docker compose up -d && cd ../.. && cd docker/sonarr && docker compose up -d && cd ../.. && cd docker/radarr && docker compose up -d && cd ../..
```

Verify: `curl -I http://<host-ip>:9696`, `:8989`, `:7878`.

### Services Needing Secrets

These need real credentials before they'll start successfully — configure them before starting the stacks.

**Transmission + Gluetun**:

```bash
cd docker/transmission-plus-gluetun
cp .env.template .env
nano .env   # fill in DESIRED_TRANSMISSION_USER/PASS, PROTON_VPN_USER (append +pmp, e.g. myusername+pmp), PROTON_VPN_PASS
docker compose up -d
cd ../..
```

Verify: `docker compose ps` shows both containers running, then `curl -I http://<host-ip>:9091` (Transmission web UI, proxied through Gluetun).

**Gluetun Port Watcher**:

Run once the stack is up:

```bash
sudo cp docker/transmission-plus-gluetun/watch-gluetun-port.service /etc/systemd/system/watch-gluetun-port.service
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

**FoundryVTT** — see section 9 for required values:

```bash
cd docker/foundryvtt
cp .env.template .env
nano .env   # fill in FOUNDRY_USERNAME, FOUNDRY_PASSWORD, FOUNDRY_ADMIN_KEY
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

**Cloudflare Tunnel** — see section 11 for required values:

```bash
cd docker/cloudflared
cp .env.template .env
nano .env   # fill in CLOUDFLARE_TUNNEL_TOKEN
docker compose up -d
cd ../..
```

Verify: `docker logs cloudflared --tail 20` shows a successful connection (no auth errors).

**RomM** — see section 12 for required values:

```bash
cd docker/romm
cp .env.template .env
nano .env   # fill in the auth key and both database passwords
docker compose up -d
cd ../..
```

Verify: `curl -I http://<host-ip>:1337`

Plain `.env` files are local runtime config/secrets and are intentionally not tracked by git.

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

With ext4 on the OS drive, you don't have snapshots. App config and data live under `/opt/digiur-net`, separate from this repo checkout, so re-cloning or wiping the repo never touches running app state. That data is still on the OS drive, though — a full OS reinstall wipes it along with everything else, so back up `/opt/digiur-net` first if you want to keep it. If OS-level changes break something:

- Docker containers are replaceable.
- `/storage` and `/mnt/nas` are independent of the OS drive.
- Worst case: reinstall the OS from scratch (takes 15 minutes) — but restore `/opt/digiur-net` from backup afterward if you want to keep existing app state.

If you want a safety net before major changes (kernel updates, Docker upgrades), use `dd` or `pv` to image the NVMe to a USB stick beforehand — clunky but effective.

## 9) FoundryVTT (Default Service)

Start Foundry manually after filling in its credentials.

Config files:

- `docker/foundryvtt/docker-compose.yml`
- `docker/foundryvtt/.env` (copy `.env.template` here and fill in its values)

Required value:

- `FOUNDRY_USERNAME`
- `FOUNDRY_PASSWORD`

Required value:

- `FOUNDRY_ADMIN_KEY`

Access:

- `http://<host-ip>:30000`

## 10) Tailscale Remote Access (Deprecated)

The Tailscale stack is retained under `deprecated/` and is not part of the active service setup.

Config files:

- `deprecated/tailscale/docker-compose.yml`
- `deprecated/tailscale/.env` (copy `.env.template` here)

Required value:

- `TS_AUTHKEY`
- `TS_HOSTNAME`

Goal:

- Keep app services LAN-only.
- Reach them remotely through VPN instead of exposing app ports directly to WAN.

## 11) Cloudflare Tunnel (Default Service)

Exposes FoundryVTT (or any other service) to the public internet without opening any inbound port on your router — `cloudflared` makes an outbound-only connection to Cloudflare, which terminates HTTPS and proxies requests through the tunnel.

Config files:

- `docker/cloudflared/docker-compose.yml`
- `docker/cloudflared/.env` (copy `.env.template` here and fill in its values)

Required value:

- `CLOUDFLARE_TUNNEL_TOKEN`

One-time manual setup, before `docker compose up -d` will do anything useful (these steps are in the Cloudflare dashboard, not this repo):

1. [Add your domain to Cloudflare](https://developers.cloudflare.com/fundamentals/manage-domains/add-site/) (changes your domain's nameservers to Cloudflare's — do this first, DNS propagation can take a while).
2. Cloudflare Zero Trust dashboard -> **Networking** -> **Tunnels** -> **Create a tunnel** -> name it -> choose **Docker** as the connector -> copy the token value out of the install command (the long string after `run --token`, not the whole command) into `CLOUDFLARE_TUNNEL_TOKEN`.
3. On the same tunnel, **Routes** tab -> **Add route** -> **Published application** -> pick a subdomain (e.g. `foundry.yourdomain.com`) -> **Service URL** = `http://10.0.20.10:30000` (your host's LAN IP + FoundryVTT's port — adjust the IP to match `hostname -I`).

Once that route exists and the container is running, the subdomain is live on the internet immediately — anyone with the link can reach it. Add a [Cloudflare Access application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/) on top if you want to restrict who can load the page (e.g. email-based login) before it even reaches Foundry's own password prompt.

Also set `FOUNDRY_PROXY_SSL: true` in `docker/foundryvtt/docker-compose.yml` once the route is live, so Foundry knows it's being served over HTTPS by the tunnel and generates correct invite links/A/V behavior.

## 12) RomM (Default Service)

RomM is part of the default service set. Start it manually from its service directory.

Config files:

- `docker/romm/docker-compose.yml`
- `docker/romm/.env` (copy `.env.template` here and fill in its values)

Hasheous is enabled in Compose and does not require an API key or account. It matches games by file hash; unmatched games may not receive Hasheous metadata.

Generate unique values for these secrets before starting the stack:

- `ROMM_AUTH_SECRET_KEY`
- `ROMM_DB_PASSWORD`

Generate the auth key with `openssl rand -hex 32` and the database password with `openssl rand -hex 24`. RomM and MariaDB root share the same database password.

Default library path:

- `/mnt/nas/roms`

## 13) First-Time App Configuration Notes

### Transmission

- Set default download location: Settings -> Downloading -> "Save files to location" = `/storage/downloads/raw`. There is no environment variable for this — it must be set once in the web UI (it persists in `/config/settings.json`).

### Prowlarr

- Add indexers.
- Add Sonarr/Radarr under Settings -> Apps using host IP.
- Add Transmission under Download Clients.

### Sonarr

- Set root folder: `/storage/downloads/processing/tv` (Sonarr renames/hardlinks here; manually transcode via HandBrake's GUI and save the finished file to `/mnt/nas/tv`).
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Radarr

- Set root folder: `/storage/downloads/processing/movies` (same pattern — manually transcode and save to `/mnt/nas/movies`).
- Configure naming, hardlinks, and upgrade behavior.
- Add Transmission download client.

### Jellyfin

- Add libraries from `/mnt/nas/tv` and `/mnt/nas/movies`.

## 14) Useful Commands

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
