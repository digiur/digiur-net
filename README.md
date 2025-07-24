# Ubuntu Setup
## Install OS
- Boot to ubuntu server USB
- For storage setup in installer select "use whole drive" and "LVM" for NVME drive (the smaller one)
- That should use 100G and leave the rest of the space on that drive free for snapshots
- Make sure the SSD is formatted and just completely free space
## Storage Setup
### Install ZFS
```bash
sudo apt update
sudo apt install zfsutils-linux acl inotify-tools
```
#### Confirm intended storage drive is "sda"
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```
#### Create zpool
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
| Command Part | Function |
|---|---|
| ashift=12               | Optimizes for SSD block sizes (4K sectors) |
| compression=zstd        | Enables zstd (efficient compression) |
| atime=off               | Disables access time updates for better performance |
| xattr=sa                | Stores extended attributes in System Attributes area instead of hidden files |
| acltype=posixacl        | Enables POSIX ACL support (for Samba shares)|
| -O mountpoint=/storage  | mounts `/storage/` |
| storage /dev/sda        | Name of pool and which drive |
#### Get zfs pool info and test compression ratio
```bash
df -h /storage
zfs list
zpool status storage
```
```bash
cd /storage
dd if=/dev/urandom bs=1M count=100 of=random.bin
ls -lh random.bin
zfs get compressratio storage
```
```bash
cd /storage
yes "this is compressible text" | head -n 100000 > text.txt
ls -lh text.txt
zfs get compressratio storage
```
### Permissions!
#### Storage Ownership
1000 is the PGID/PUID that the containers use
```bash
sudo chown -R 1000:1000 /storage
```
#### Ensure New Files Keep Correct Group
This ensures that if a container or a script creates something, it'll stay within group `1000`
```bash
sudo chmod g+s /storage
```
#### Set Default Permissions with ACL
```bash
sudo setfacl -m group:1000:rwx /storage
sudo setfacl -d -m group:1000:rwx /storage
sudo setfacl -d -m mask::rwx /storage
```
- Grants read/write/execute access to group `1000` on `/storage`
- Newly created files/folders inside `/storage` will inherit `rwx` permissions for group `1000`
- Ensures the maximum allowed permissions don’t accidentally restrict the `rwx` granted to group `1000`.
Inspect results with:
```bash
getfacl /storage
```
# digiur-net
## Quick Setup digiur-net
```bash
wget -qO- https://raw.githubusercontent.com/digiur/digiur-net/main/scripts/quickstart.sh | bash
```
This will download and run a quick-setup script that will clone this repo, and add the current user to the docker user group.
### Follow the instructions on screen
- Log out and log back in for the user group change to take effect.
- Run this script again
```bash
./digiur-net/scripts/quickstart.sh
```
### Fill out VPN Credentialls
Follow the instructions in the file that's open for editing
`ctrl + x` to exit
`y` to save
`enter` to use the same file name
## Post Install Setup
### Transmission port updater
Install inotify-tools
```bash
sudo apt update
sudo apt install inotify-tools
```
Copy .system file to correct location
```bash
sudo cp ./digiur-net/scripts/services/watch-gluetun-port.service /etc/systemd/system/
```
Start it
```bash
sudo systemctl daemon-reload
sudo systemctl enable watch-gluetun-port
sudo systemctl start watch-gluetun-port
sudo systemctl restart watch-gluetun-port
sudo systemctl status watch-gluetun-port
sudo systemctl stop watch-gluetun-port
```
Check logs
```bash
journalctl -u watch-gluetun-port
```
Live view
```bash
journalctl -f -u watch-gluetun-port
```
Manually edit file
```bash
echo 65000 | sudo tee ./digiur-net/docker/transmission-plus-gluetun/gluetun/forwarded_port
echo 61234 > /tmp/tmpport
sudo mv /tmp/tmpport ~/digiur-net/docker/transmission-plus-gluetun/gluetun/forwarded_port
```
Chack from transmission container what ports it's listening to
```bash
docker compose -f ./digiur-net/docker/transmission-plus-gluetun/docker-compose.yml exec transmissionplus netstat -tulnp
```
Restart gluetun to trigger _it_ to write a port (should cascade a restart of transmission)
```bash
docker compose -f ./digiur-net/docker/transmission-plus-gluetun/docker-compose.yml restart gluetun
```
### Snapshot
#### Fix Swap
```bash
sudo lvcreate -L 8G -n swap ubuntu-vg
sudo mkswap /dev/ubuntu-vg/swap
swapon --show
sudo swapoff -a
sudo swapon /dev/ubuntu-vg/swap
swapon --show
sudo nano /etc/fstab
```
replace old swap line with `/dev/ubuntu-vg/swap none swap sw 0 0`
delete old swap file `/swap.img`
#### Set Snapshot
```bash
sudo lvs
sudo lvcreate --snapshot --size 100G --name base-install /dev/ubuntu-vg/ubuntu-lv
```
#### Mount Snapshot (For lookin at)
```bash
sudo mkdir -p /mnt/base-install
sudo mount -o ro /dev/ubuntu-vg/base-install /mnt/base-install
mount | grep base-install
ls /mnt/base-install
```
### Transmission
Save directory options should be set to `/storage/` somewhere

### Sonarr, Radarr, Prowlarr
Login to each

make `tv` dir in `/storage`

make `movies` dir in `/storage`
<!-- ```bash
cd /storage/
mkdir tv
mkdir movies
```
```bash
sudo chown -R digiur:digiur /storage
```
All files and directories inside `/storage` are now owned by user `digiur` and group `digiur`.
```bash
sudo chmod -R 775 /storage
```
- `7` = read + write + execute for **owner**
- `7` = read + write + execute for **group**
- `5` = read + execute for **others**
Everyone in the `digiur` group can read/write/execute files in `/storage`, and other users can read and enter directories (but not write).
```bash
sudo find /storage -type d -exec chmod g+s {} \;
```
All directories in `/storage` will now **keep the `digiur` group** for any new files/folders created inside them — even by Docker containers. -->
### Prowlarr
Add indexers to prowlarr

Add sonarr and radarr in settings -> apps (replace localhost with IP address)

Add transmission in settings -> download clients (username and password set during install)

Change Log Level to info
### Sonarr
- Media settings
  - naming is fun
  - hardlinks yes
  - do not upgrade automatically
  - add tv root directory

- Add transmission in download client
  - Category would be good
### Radarr
- Media settings
  - naming is fun
  - hardlinks yes
  - do not upgrade automatically
  - add movies root directory
- Add transmission in download client
  - Category would be good
Here’s a set of targeted recommendations based on your hardware and running services, showing **exactly what each tweak does**, its **power-saving benefit**, and the **potential trade-offs** so you can pick and choose:

| **Tweak**                                                                                                                            | **What It Does**                                               | **Power Benefit**                                     | **Trade-Offs / Consequences**                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **CPU governor → `powersave`**<br>`sudo apt install cpufrequtils`<br>`sudo cpufreq-set -r -g powersave`                              | Cuts clock speed aggressively when idle                        | 5–15 W less at idle on N100                           | Slower responsiveness under bursty load (e.g. compiling)                                          |
| **Disable unused services**<br>e.g. `sudo systemctl disable fwupd ModemManager multipathd udisks2 upower`                            | Stops background daemons you don’t need                        | \~0.5–2 W per service                                 | If you need firmware updates (fwupd) or power management (upower) later, you’ll have to re-enable |
| **`noatime` in `/etc/fstab`**<br>Change<br>`/dev/mapper/ubuntu--vg-ubuntu--lv / ext4 defaults 0 1`<br>to<br>`… defaults,noatime 0 1` | Avoids writes on every file read                               | Reduces SSD writes and a few CPU cycles per I/O       | You lose access-time updates seen by some forensic tools (rarely used)                            |
| **`vm.dirty_ratio=5`** in `/etc/sysctl.d/99-power.conf`                                                                              | Flushes dirty pages more frequently in smaller batches         | Lower burst of disk I/O, slightly steadier power draw | Increases I/O interrupts slightly—minimal risk if you have a UPS                                  |
| **USB autosuspend**<br>`echo auto > /sys/bus/usb/devices/usbX/power/control`                                                         | Suspends idle USB controllers and devices                      | 0.1–1 W per controller                                | Some USB drives or dongles may disconnect; you can whitelist critical ones in TLP                 |
| **Ethernet power-save**<br>`sudo ethtool -s enp1s0 wol d`                                                                            | Disables Wake-on-LAN                                           | \~0.2 W saved on NIC                                  | You lose remote-wake capability                                                                   |
| **Install TLP**<br>`sudo apt install tlp`<br>`sudo tlp start`                                                                        | Auto-tunes many of the above and more (disk, PCIe, runtime PM) | Consolidates savings—often 5–10 W total               | Some tunables may interfere with time-sensitive workloads; you can override in `/etc/tlp.conf`    |
| **Reduce download slots in Transmission**<br>Web UI → Preferences → Bandwidth                                                        | Fewer simultaneous peers → fewer threads and sockets           | <0.5 W per 10 slots reduced                           | Slightly slower torrent peer discovery and throughput                                             |
| **Disable LPD in Transmission**<br>`"lpd-enabled": false` in `settings.json`                                                         | Turns off LAN peer scanning                                    | Negligible power (but every little bit)               | No effect on public torrents                                                                      |
| **Fan curve / undervolt**<br>BIOS tweak or `intel-undervolt`                                                                         | Lowers fan speed and CPU voltage                               | 2–5 W less, much quieter                              | Risk of instability if undervolted too far                                                        |

---

### How to apply the top picks:

1. **Set the CPU governor**

   ```bash
   sudo apt install cpufrequtils
   echo 'GOVERNOR="powersave"' | sudo tee /etc/default/cpufrequtils
   sudo systemctl restart cpufrequtils
   ```

2. **Add `noatime`** to `/etc/fstab` for your root LV:

   ```diff
   - /dev/mapper/ubuntu--vg-ubuntu--lv / ext4 defaults 0 1
   + /dev/mapper/ubuntu--vg-ubuntu--lv / ext4 defaults,noatime 0 1
   ```

   Then `sudo mount -o remount /`.

3. **Tune dirty ratio**: create `/etc/sysctl.d/99-power.conf` with:

   ```
   vm.dirty_ratio = 5
   ```

   and run `sudo sysctl --system`.

4. **Disable extra services**:

   ```bash
   sudo systemctl disable fwupd ModemManager multipathd udisks2 upower
   ```

5. **Install and start TLP** for an all-in-one approach:

   ```bash
   sudo apt install tlp
   sudo tlp start
   ```

After these, rerun `powertop` (or measure on your meter) to see cumulative savings. Adjust more aggressively (USB suspend, undervolt) once you’ve confirmed system stability.
