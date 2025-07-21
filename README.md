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