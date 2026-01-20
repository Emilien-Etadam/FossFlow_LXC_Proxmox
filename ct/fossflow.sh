#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
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

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/fossflow ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/stan-smith/FossFLOW/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
  if [[ -f /opt/${APP}_version.txt ]] && [[ "${RELEASE}" == "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  else
    msg_info "Updating ${APP} to v${RELEASE}"
    systemctl stop fossflow
    cd /opt/fossflow
    git fetch --all --tags --prune
    git checkout "v${RELEASE}"
    npm install &>/dev/null
    npm run build:lib &>/dev/null
    npm run build:app &>/dev/null
    echo "${RELEASE}" >/opt/${APP}_version.txt
    systemctl start fossflow
    msg_ok "Updated ${APP} to v${RELEASE}"
  fi
  exit
}

start

# Custom build_container function for external repository
function build_container() {
  msg_info "Creating LXC Container"
  DISK_REF="$DISK_SIZE"
  if [ "$var_os" == "alpine" ]; then
    OSTYPE=alpine
    OSVERSION=${OSVERSION:-3.19}
    TEMPLATE="$CTID:vztmpl/$var_os-$var_version-default_*_amd64.tar.xz"
  else
    OSTYPE=$var_os
    OSVERSION=$var_version
    TEMPLATE="$CTID:vztmpl/$var_os-$var_version-standard_*_amd64.tar.zst"
  fi

  pct create "$CTID" "$PCT_OSTEMPLATE" \
    -arch $(dpkg --print-architecture) \
    -cores "$CORE_COUNT" \
    -description "<div align='center'><img src='https://raw.githubusercontent.com/stan-smith/FossFLOW/master/packages/fossflow-app/public/favicon.svg' width='50'/><h3>FossFLOW LXC</h3></div>" \
    -features nesting=$var_nesting \
    -hostname "$HN" \
    -memory "$RAM_SIZE" \
    -net0 name=eth0,bridge=$BRG,ip=$NET \
    -onboot 1 \
    -ostype "$OSTYPE" \
    -password "$PW" \
    -rootfs $DISK_REF \
    -swap "$var_swap" \
    -tags proxmox-helper-scripts \
    -unprivileged $var_unprivileged
  msg_ok "LXC Container $CTID was successfully created"

  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"

  msg_info "Configuring LXC Container"
  sleep 2
  pct push "$CTID" <(echo "export FUNCTIONS_FILE_PATH='$FUNCTIONS_FILE_PATH'") /etc/profile.d/env.sh

  # Download and execute install script from this repository
  INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Emilien-Etadam/FossFlow_LXC_Proxmox/main/ct/fossflow-install"
  INSTALL_SCRIPT=$(curl -fsSL "$INSTALL_SCRIPT_URL") || {
    msg_error "Failed to download install script from $INSTALL_SCRIPT_URL"
    exit 1
  }

  pct exec "$CTID" -- bash -c "$INSTALL_SCRIPT" || {
    msg_error "Installation failed"
    exit 1
  }

  msg_ok "Customized LXC Container"
}

build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
