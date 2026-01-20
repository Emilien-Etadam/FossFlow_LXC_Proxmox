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
DISK_SIZE="4"
CPU_CORES="2"
RAM_SIZE="1024"
BRIDGE="vmbr0"
HOSTNAME="fossflow"
PASSWORD=$(openssl rand -base64 12)

# Function to select storage
function select_storage() {
  local storage_type=$1
  local content_type=$2

  mapfile -t STORAGE_MENU < <(pvesm status -content "$content_type" | awk 'NR>1 {print $1}')

  if [ ${#STORAGE_MENU[@]} -eq 0 ]; then
    msg_error "No storage found that supports $content_type"
    exit 1
  fi

  if [ ${#STORAGE_MENU[@]} -eq 1 ]; then
    echo "${STORAGE_MENU[0]}"
    return
  fi

  msg_info "Select $storage_type storage:"
  PS3="Enter selection: "
  select storage in "${STORAGE_MENU[@]}"; do
    if [[ -n "$storage" ]]; then
      echo "$storage"
      return
    else
      msg_error "Invalid selection"
    fi
  done
}

# Select storage for templates
msg_info "Selecting storage for templates..."
TEMPLATE_STORAGE=$(select_storage "Template" "vztmpl")

# Select storage for containers
msg_info "Selecting storage for container..."
CONTAINER_STORAGE=$(select_storage "Container" "rootdir")

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
echo -e "  💿  Template Storage: ${BL}${TEMPLATE_STORAGE}${CL}"
echo -e "  📁  Container Storage: ${BL}${CONTAINER_STORAGE}${CL}"
echo -e ""
msg_info "Creating a ${APP} LXC using the above default settings"
echo -e ""

# Check if template exists and download if needed
msg_info "Checking for template"

# First, check what's already downloaded
EXISTING_TEMPLATE=$(pveam list $TEMPLATE_STORAGE 2>/dev/null | grep "debian-12-standard" | head -1 | awk '{print $1}')

if [ -n "$EXISTING_TEMPLATE" ]; then
  # Extract just the filename from "storage:vztmpl/filename"
  TEMPLATE_NAME=$(basename "$EXISTING_TEMPLATE")
  TEMPLATE_PATH="$EXISTING_TEMPLATE"
  msg_ok "Template already downloaded: $TEMPLATE_NAME"
else
  # List available templates and find debian-12-standard
  msg_info "Fetching available templates..."
  pveam update >/dev/null 2>&1 || true

  TEMPLATE_NAME=$(pveam available -section system | grep "debian-12-standard" | head -1 | awk '{print $2}')

  if [ -z "$TEMPLATE_NAME" ]; then
    msg_error "Could not find debian-12-standard template"
    exit 1
  fi

  msg_info "Downloading template: $TEMPLATE_NAME"
  pveam download $TEMPLATE_STORAGE $TEMPLATE_NAME || {
    msg_error "Failed to download template"
    exit 1
  }
  TEMPLATE_PATH="$TEMPLATE_STORAGE:vztmpl/$TEMPLATE_NAME"
  msg_ok "Template downloaded: $TEMPLATE_NAME"
fi

# Create container
msg_info "Creating LXC Container"
pct create $CTID "$TEMPLATE_PATH" \
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
  -rootfs $CONTAINER_STORAGE:$DISK_SIZE \
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
