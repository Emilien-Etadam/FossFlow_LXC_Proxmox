#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Emilien-Etadam
# License: MIT | https://github.com/Emilien-Etadam/FossFlow_LXC_Proxmox/raw/main/LICENSE
# Source: https://github.com/stan-smith/FossFLOW

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  git \
  ca-certificates \
  gnupg
msg_ok "Installed Dependencies"

msg_info "Installing Node.js 20.x"
$STD bash -c "$(curl -fsSL https://deb.nodesource.com/setup_20.x)"
$STD apt-get install -y nodejs
msg_ok "Installed Node.js $(node -v)"

msg_info "Installing FossFLOW"
RELEASE=$(curl -fsSL https://api.github.com/repos/stan-smith/FossFLOW/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
cd /opt
git clone -b "v${RELEASE}" --depth 1 https://github.com/stan-smith/FossFLOW.git fossflow
cd /opt/fossflow
$STD npm install
$STD npm run build:lib
$STD npm run build:app
echo "${RELEASE}" >/opt/FossFLOW_version.txt
msg_ok "Installed FossFLOW v${RELEASE}"

msg_info "Creating Data Directory"
mkdir -p /opt/fossflow-data/diagrams
msg_ok "Created Data Directory"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/fossflow.service
[Unit]
Description=FossFLOW Isometric Diagramming Tool
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/fossflow
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=ENABLE_SERVER_STORAGE=true
Environment=STORAGE_PATH=/opt/fossflow-data/diagrams
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now fossflow
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
