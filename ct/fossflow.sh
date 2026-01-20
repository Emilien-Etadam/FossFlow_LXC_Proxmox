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

# Function to select storage with detailed info
function select_storage() {
  local storage_type=$1
  local content_type=$2

  # Get storage info with usage
  mapfile -t STORAGE_LIST < <(pvesm status -content "$content_type" | awk 'NR>1')

  if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
    msg_error "No storage found that supports $content_type" >&2
    exit 1
  fi

  # Extract just storage names for menu
  mapfile -t STORAGE_MENU < <(printf '%s\n' "${STORAGE_LIST[@]}" | awk '{print $1}')

  if [ ${#STORAGE_MENU[@]} -eq 1 ]; then
    STORAGE_NAME="${STORAGE_MENU[0]}"
    # Get storage info
    STORAGE_INFO=$(printf '%s\n' "${STORAGE_LIST[@]}" | grep "^$STORAGE_NAME")
    echo -e "${GN}✔️${CL}   Storage $STORAGE_NAME (${storage_type})" >&2
    echo "$STORAGE_NAME"
    return
  fi

  # Display storage options with details - redirect to stderr
  echo "" >&2
  echo -e "${BL}[INFO]${CL} Select $storage_type storage:" >&2
  for i in "${!STORAGE_LIST[@]}"; do
    local line="${STORAGE_LIST[$i]}"
    local name=$(echo "$line" | awk '{print $1}')
    local type=$(echo "$line" | awk '{print $2}')
    local avail=$(echo "$line" | awk '{print $4}')
    local used=$(echo "$line" | awk '{print $5}')
    printf "  %d) ${BL}%-12s${CL} (%s) [Free: %s  Used: %s]\n" $((i+1)) "$name" "$type" "$avail" "$used" >&2
  done
  echo "" >&2

  while true; do
    read -p "Select storage [1-${#STORAGE_MENU[@]}]: " choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#STORAGE_MENU[@]}" ]; then
      SELECTED="${STORAGE_MENU[$((choice-1))]}"
      echo -e "${GN}✔️${CL}   Storage $SELECTED [${STORAGE_LIST[$((choice-1))]}]" >&2
      echo "$SELECTED"
      return
    else
      echo -e "${RD}[ERROR]${CL} Invalid selection. Please enter a number between 1 and ${#STORAGE_MENU[@]}" >&2
    fi
  done
}

# Select storage for templates
TEMPLATE_STORAGE=$(select_storage "Template" "vztmpl")

# Select storage for containers
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

  # Get template name without spaces - using column 2 from system section
  TEMPLATE_NAME=$(pveam available | awk '/system.*debian-12-standard/ {print $2; exit}')

  if [ -z "$TEMPLATE_NAME" ]; then
    msg_error "Could not find debian-12-standard template"
    exit 1
  fi

  msg_info "Downloading template: $TEMPLATE_NAME"
  # Use quotes to prevent word splitting
  pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME" || {
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
