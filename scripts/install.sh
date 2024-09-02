#!/usr/bin/bash
source ./digiur-net/scripts/source.sh
Welcome_Logo
echo "...INSTALL!"

echo "Step 0: Set Swap Size"
Set_Swap_Size

echo "Step 1: Install Depends"
Update_Package_Resource
Install_Depends
Upgrade_Package_Resource
Check_Dependency_Installation

echo "Step 2: Check And Install Docker"
Install_Docker
Check_Docker_Install

echo "Step 3: Digiur-net Setup"
Digiur_Net_Setup

echo "Step 4: Clear Term and Show Welcome Banner"
Welcome_Banner
