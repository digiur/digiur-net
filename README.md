# digiur-net
### Quick Setup digiur-net

This assumes a machine with a smaller (likely nvme) drive for os and app files, and a larger (likely ssd) drive for large media files.

1. Install Ubuntu Server 24.04
    - Mount the small disk to `/`
    - Mount the large disk to `/storage`

2. Run this script
```sh
wget -qO- https://raw.githubusercontent.com/digiur/digiur-net/main/scripts/quickstart.sh | bash
```
This will download and run a quick-setup script that will clone this repo, and add the current user to the docker user group.

3. Log out and log back in for the user group change to take effect.
    - Take this time to edit `./transmission+gluetun.env` with your VPN credentials

4. Run this script again
```sh
wget -qO- https://raw.githubusercontent.com/digiur/digiur-net/main/scripts/quickstart.sh | bash
```
This time it will run the full install.

5. Everything should be fine...

### Post Install Setup

#### Portainer

Get forwarded port from gluten's logs.

#### Transmission

Put the port in gluten's web GUI. It will have to be updated like that periodically... 
Checking forwarded port: https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md#test-it
Automate forwarded port: https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/port-forwarding.md

Save directory options should be setup automatically

#### Sonarr, Radarr, Prowlarr

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

#### Prowlarr

Add indexers to prowlarr

Add sonarr and radarr in settings -> apps (replace localhost with IP address)

Add transmission in settings -> download clients (username and password set during install)

Change Log Level to info

#### Sonarr

- Media settings
  - naming is fun
  - hardlinks yes
  - do not upgrade automatically
  - add tv root directory

- Add transmission in download client
  - Category would be good

#### Radarr

- Media settings
  - naming is fun
  - hardlinks yes
  - do not upgrade automatically
  - add movies root directory

- Add transmission in download client
  - Category would be good
