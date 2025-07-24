#!/usr/bin/bash

source ./scripts/source.sh

Welcome_Logo || show 1 "Failed to display welcome logo"

# Install Start
show_time
show 2 "*** INSTALL process start! ***"

show 2 "Step 0: Set swap size"
Set_Swap_Size || show 1 "Failed to set swap size"
show 0 "Swap size set successfully..."

# Step 1: Install dependencies
show_time
show 2 "Step 1: Instal dependencies"
Update_Package_Resource || show 1 "Failed to update package resource"
show 0 "Package resource updated..."

Install_Depends || show 1 "Failed to install dependencies"
show 0 "Dependencies installed..."

Check_Dependency_Installation || show 1 "Dependency installation check failed"
show 0 "Dependency installation check passed..."

# Step 2: Install Docker
show_time
show 2 "Step 2: Install Docker"
Install_Docker || show 1 "Failed to install Docker"
show 0 "Docker installed..."

Check_Docker_Install || show 1 "Docker installation check failed"
show 0 "Docker installation check passed...."

# Step 3: Upgrade package resource and re-check dependencies
show_time
show 2 "Step 3: Final Dependency Check"
Upgrade_Package_Resource || show 1 "Failed to upgrade package resource"
show 0 "Package resource upgraded..."

Check_Dependency_Installation || show 1 "Dependency re-check failed"
show 0 "Dependency re-check passed..."

Check_Docker_Install || show 1 "Docker re-check failed"
show 0 "Docker re-check passed..."

# Step 4: Set up digiur-net
show_time
show 2 "Step 4: Set up digiur-net"
Validate_Transmission_Creds || show 1 "Failed to validate Transmission credentials"
show 0 "Transmission credentials validated..."

Handle_Dashy_IP_Config || show 1 "Failed to update Dashy IPs"
show 0 "Injected host IP into Dashy config..."

Digiur_Net_Setup || show 1 "Failed to start up digiur-net"
show 0 "Digiur-net setup completed successfully..."

Welcome_Banner || show 1 "Failed to display welcome banner"

show 2 "*** INSTALL process completed successfully! ***"
show_time
