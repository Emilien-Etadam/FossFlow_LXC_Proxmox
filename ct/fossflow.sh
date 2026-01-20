#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Emilien-Etadam
# License: MIT | https://github.com/Emilien-Etadam/FossFlow_LXC_Proxmox/raw/main/LICENSE
# Source: https://github.com/stan-smith/FossFLOW

# Color codes for output
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;92m'
YW='\033[1;33m'
CL='\033[m'

function msg_info() {
  echo -e "${BL}[INFO]${CL} $1"
}

function msg_ok() {
  echo -e "${GN}[OK]${CL} $1"
}

function msg_error() {
  echo -e "${RD}[ERROR]${CL} $1"
}

# Default configuration
APP="FossFLOW"
CTID=$(pvesh get /cluster/nextid)
TEMPLATE="debian-12-standard"
STORAGE="local"
DISK_SIZE="4"
CPU_CORES="2"
RAM_SIZE="1024"
BRIDGE="vmbr0"
HOSTNAME="fossflow"
PASSWORD=$(openssl rand -base64 12)

# Display configuration
clear
cat << "EOF"
    ______              ______ __    ______ _       __
   / ____/___  _________/ ____// /   / __ \ |     / /
  / /_  / __ \/ ___/ ___/ /_  / /   / / / / | /| / /
 / __/ / /_/ (__  |__  ) __/ / /___/ /_/ /| |/ |/ /
/_/    \____/____/____/_/   /_____/\____/ |__/|__/

EOF

msg_info "Using Default Settings"
echo -e "  🆔  Container ID: ${BL}${CTID}${CL}"
echo -e "  🖥️  Operating System: ${BL}Debian 12${CL}"
echo -e "  📦  Container Type: ${BL}Unprivileged${CL}"
echo -e "  💾  Disk Size: ${BL}${DISK_SIZE} GB${CL}"
echo -e "  🧠  CPU Cores: ${BL}${CPU_CORES}${CL}"
echo -e "  🛠️  RAM Size: ${BL}${RAM_SIZE} MiB${CL}"
echo -e ""
msg_info "Creating a ${APP} LXC using the above default settings"
echo -e ""

# Check if template exists
msg_info "Checking for template"
TEMPLATE_FILE=$(pveam list $STORAGE | grep -m 1 "$TEMPLATE" | awk '{print $1}')
if [ -z "$TEMPLATE_FILE" ]; then
  msg_info "Downloading template..."
  pveam download $STORAGE $TEMPLATE-*.tar.zst || {
    msg_error "Failed to download template"
    exit 1
  }
  TEMPLATE_FILE=$(pveam list $STORAGE | grep -m 1 "$TEMPLATE" | awk '{print $1}')
fi
msg_ok "Template: $TEMPLATE_FILE"

# Create container
msg_info "Creating LXC Container"
pct create $CTID $STORAGE:vztmpl/$TEMPLATE_FILE \
  -arch amd64 \
  -cores $CPU_CORES \
  -description "FossFLOW - Isometric Infrastructure Diagram Tool" \
  -features nesting=1 \
  -hostname $HOSTNAME \
  -memory $RAM_SIZE \
  -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  -onboot 1 \
  -ostype debian \
  -password $PASSWORD \
  -rootfs $STORAGE:$DISK_SIZE \
  -swap 512 \
  -unprivileged 1 || {
    msg_error "Failed to create container"
    exit 1
  }
msg_ok "LXC Container $CTID was successfully created"

# Start container
msg_info "Starting LXC Container"
pct start $CTID
sleep 5
msg_ok "Started LXC Container"

# Wait for network
msg_info "Waiting for network..."
for i in {1..30}; do
  if pct exec $CTID -- ping -c 1 8.8.8.8 &>/dev/null; then
    msg_ok "Network is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    msg_error "Network timeout"
    exit 1
  fi
  sleep 2
done

# Download and execute install script
msg_info "Downloading installation script"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow-install"
INSTALL_SCRIPT=$(curl -fsSL "$INSTALL_SCRIPT_URL") || {
  msg_error "Failed to download install script from $INSTALL_SCRIPT_URL"
  exit 1
}
msg_ok "Downloaded installation script"

msg_info "Installing FossFLOW (this may take several minutes...)"
pct exec $CTID -- bash -c "$INSTALL_SCRIPT" || {
  msg_error "Installation failed"
  exit 1
}
msg_ok "FossFLOW installed successfully"

# Get IP address
IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

msg_ok "Completed Successfully!"
echo -e ""
echo -e "${GN}🚀  FossFLOW setup has been successfully initialized!${CL}"
echo -e "${YW}💡   Access it using the following URL:${CL}"
echo -e "    ${GN}🌐  http://${IP}:3000${CL}"
echo -e ""
echo -e "${YW}📝  Container ID: ${CL}${CTID}"
echo -e "${YW}🔐  Root Password: ${CL}${PASSWORD}"
echo -e ""
