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
sudo apt install zfsutils-linux
```
#### Confirm intended storage drive is "sda"
`lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL`
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
#### Ensure New Files Keep Correct Group**
This ensures that if a container or a script creates something, it'll stay within group `1000`
```bash
sudo chmod g+s /storage
```
#### Set Default Permissions with ACL**
```bash
sudo apt install acl
sudo setfacl -d -m group:1000:rwx /storage
```
This sets a **default ACL**, so even newly created files (from containers or scripts) will:
* Have group `1000`
* Be readable/writable/executable by the group
Inspect with:
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
wget -qO- https://raw.githubusercontent.com/digiur/digiur-net/main/scripts/quickstart.sh | bash
```
### Fill out VPN Credentialls
Follow the instructions in the file that's open for editing
`ctrl + x` to exit
`y` to save
`enter` to use the same file name


## Post Install Setup

### Portainer

Get forwarded port from gluten's logs.

### Transmission

Put the port in gluten's web GUI. It will have to be updated like that periodically... 
Checking forwarded port: https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md#test-it
Automate forwarded port: https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/port-forwarding.md

Save directory options should be setup automatically

### Sonarr, Radarr, Prowlarr

Login to each

make `tv` dir in `/storage`
make `movies` dir in `/storage`

```bash
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
* `7` = read + write + execute for **owner**
* `7` = read + write + execute for **group**
* `5` = read + execute for **others**

Everyone in the `digiur` group can read/write/execute files in `/storage`, and other users can read and enter directories (but not write).

```bash
sudo find /storage -type d -exec chmod g+s {} \;
```

All directories in `/storage` will now **keep the `digiur` group** for any new files/folders created inside them — even by Docker containers.

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


