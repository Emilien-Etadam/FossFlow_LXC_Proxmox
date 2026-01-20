#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Emilien-Etadam
# License: MIT | https://github.com/Emilien-Etadam/FossFlow_LXC_Proxmox/raw/main/LICENSE
# Source: https://github.com/stan-smith/FossFLOW

APP="FossFLOW"
var_tags="diagram;infrastructure"
var_cpu="2"
var_ram="1024"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

# Color codes
RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# Functions
msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# Header
header_info() {
  clear
  cat <<"EOF"
    ______              ______ __    ______ _       __
   / ____/___  _________/ ____// /   / __ \ |     / /
  / /_  / __ \/ ___/ ___/ /_  / /   / / / / | /| / /
 / __/ / /_/ (__  |__  ) __/ / /___/ /_/ /| |/ |/ /
/_/    \____/____/____/_/   /_____/\____/ |__/|__/

EOF
}

# Storage selection
storage_menu() {
  local STORAGE_TYPE=$1
  local CONTENT_TYPE=$2

  # Get storage list
  STORAGE_LIST=()
  STORAGE_MENU=()
  while IFS= read -r line; do
    TAG=$(echo "$line" | awk '{print $1}')
    TYPE=$(echo "$line" | awk '{printf "%-10s", $2}')
    FREE=$(numfmt --to iec --format "%.2f" $(echo "$line" | awk '{printf "%d\n", $4*1024}'))
    USED=$(numfmt --to iec --format "%.2f" $(echo "$line" | awk '{printf "%d\n", $5*1024}'))
    ITEM="  Type: $TYPE | Free: $FREE"
    OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
    STORAGE_LIST+=("$TAG")
  done < <(pvesm status -content "$CONTENT_TYPE" | awk 'NR>1')

  # Check if storage found
  if [ ${#STORAGE_MENU[@]} -eq 0 ]; then
    msg_error "No storage found supporting $CONTENT_TYPE"
    exit 1
  fi

  # Auto-select if only one
  if [ ${#STORAGE_MENU[@]} -eq 3 ]; then
    echo "${STORAGE_LIST[0]}"
    msg_info "Using ${STORAGE_LIST[0]} for $STORAGE_TYPE"
    return
  fi

  # Show menu
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage" --radiolist \
    "\nSelect the $STORAGE_TYPE storage location:\n" \
    16 $(($MSG_MAX_LENGTH + 23)) 6 \
    "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done

  echo "$STORAGE"
}

# Variables setup
variables() {
  NSAPP=$(echo ${APP,,} | tr -d ' ')

  # Get next container ID
  NEXTID=$(pvesh get /cluster/nextid)
  CTID=$NEXTID

  # Select storages
  msg_info "Selecting Template Storage"
  TEMPLATE_STORAGE=$(storage_menu "Template" "vztmpl")
  msg_ok "Selected Template Storage: $TEMPLATE_STORAGE"

  msg_info "Selecting Container Storage"
  CONTAINER_STORAGE=$(storage_menu "Container" "rootdir")
  msg_ok "Selected Container Storage: $CONTAINER_STORAGE"

  # Set other variables
  HN="$NSAPP"
  DISK_SIZE="${var_disk}"
  CORE_COUNT="${var_cpu}"
  RAM_SIZE="${var_ram}"
  BRG="vmbr0"
  MAC=""
  VLAN=""
  MTU=""
  NET="dhcp"
  PW=$(openssl rand -base64 12)
}

# Start
start() {
  # Check for template
  msg_info "Checking for Debian 12 Template"

  # Check if already downloaded
  if pveam list $TEMPLATE_STORAGE 2>/dev/null | grep -q "debian-12-standard"; then
    PCT_OSTEMPLATE=$(pveam list $TEMPLATE_STORAGE | grep "debian-12-standard" | head -1 | awk '{print $1}')
    msg_ok "Using existing template"
  else
    # Download template
    msg_info "Downloading Debian 12 Template"
    pveam update >/dev/null 2>&1 || true
    TEMPLATE_NAME=$(pveam available | awk '/system.*debian-12-standard/ {print $2; exit}')

    if [ -z "$TEMPLATE_NAME" ]; then
      msg_error "Could not find debian-12-standard template"
      exit 1
    fi

    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE_NAME" >/dev/null 2>&1 || {
      msg_error "Failed to download template"
      exit 1
    }

    PCT_OSTEMPLATE="$TEMPLATE_STORAGE:vztmpl/$TEMPLATE_NAME"
    msg_ok "Downloaded template"
  fi
}

# Build container
build_container() {
  msg_info "Creating LXC Container"

  pct create $CTID "$PCT_OSTEMPLATE" \
    -arch amd64 \
    -cores $CORE_COUNT \
    -description "FossFLOW - Isometric Infrastructure Diagram Tool" \
    -features nesting=1 \
    -hostname "$HN" \
    -memory $RAM_SIZE \
    -net0 name=eth0,bridge=$BRG,ip=$NET \
    -onboot 1 \
    -ostype debian \
    -password "$PW" \
    -rootfs "$CONTAINER_STORAGE:$DISK_SIZE" \
    -swap 512 \
    -tags proxmox-helper-scripts \
    -unprivileged $var_unprivileged >/dev/null || {
      msg_error "Failed to create LXC Container"
      exit 1
    }

  msg_ok "LXC Container $CTID Created"

  # Start container
  msg_info "Starting LXC Container"
  pct start $CTID
  msg_ok "Started LXC Container"

  # Wait for network
  msg_info "Waiting for Container to be ready"
  sleep 5

  for i in {1..30}; do
    if pct exec $CTID -- ping -c 1 8.8.8.8 >/dev/null 2>&1; then
      break
    fi
    if [ $i -eq 30 ]; then
      msg_error "Network timeout"
      exit 1
    fi
    sleep 2
  done
  msg_ok "Container is ready"

  # Download and run install script
  msg_info "Installing $APP"
  INSTALL_URL="https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow-install"

  pct exec $CTID -- bash -c "$(curl -fsSL $INSTALL_URL)" || {
    msg_error "Installation failed"
    exit 1
  }

  msg_ok "$APP Installed"
}

# Description
description() {
  IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  echo -e "\n ${CM} ${GN}Completed Successfully!${CL}\n"
  echo -e " ${APP} should be reachable at ${YW}http://${IP}:3000${CL}\n"
  echo -e " ${YW}Container ID: ${CL}$CTID"
  echo -e " ${YW}Root Password: ${CL}$PW\n"
}

# Update function
function update_script() {
  header_info

  if [[ ! -d /opt/fossflow ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/stan-smith/FossFLOW/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')

  if [[ -f /opt/${APP}_version.txt ]] && [[ "${RELEASE}" == "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  else
    msg_info "Updating ${APP} to v${RELEASE}"
    systemctl stop fossflow-frontend
    systemctl stop fossflow-backend
    cd /opt/fossflow
    git fetch --all --tags --prune
    git checkout "v${RELEASE}"
    npm install &>/dev/null
    npm run build:lib &>/dev/null
    npm run build:app &>/dev/null
    echo "${RELEASE}" >/opt/${APP}_version.txt
    systemctl start fossflow-backend
    systemctl start fossflow-frontend
    msg_ok "Updated ${APP} to v${RELEASE}"
  fi
  exit
}

# Main execution
header_info
variables
start
build_container
description
