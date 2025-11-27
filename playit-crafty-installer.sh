#!/bin/bash
# Debian 13 script to install Crafty Controller
# Author: Ray

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
NC="\e[0m"

error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

step() {
    echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Install :^)
step "Updating package list and installing dependencies..."
sudo apt update || error_exit "Failed to update apt repositories."
sudo apt install -y git python3 python3-dev python3-pip python3.13-venv openjdk-21-jdk openjdk-21-jre \
|| error_exit "Dependency installation failed."

step "Creating Crafty user account..."
if id "crafty" &>/dev/null; then
    warn "User 'crafty' already exists. Skipping."
else
    sudo useradd crafty -s /bin/bash || error_exit "Failed to create user 'crafty'."
fi

step "Creating directory structure..."
sudo mkdir -p /var/opt/minecraft/crafty /var/opt/minecraft/server || error_exit "Failed creating directories."
sudo chown -R crafty:crafty /var/opt/minecraft || error_exit "Failed setting permissions."

step "Cloning Crafty Controller repository..."
sudo -u crafty git clone https://gitlab.com/crafty-controller/crafty-4.git /var/opt/minecraft/crafty/crafty-4 \
|| error_exit "Failed to clone Crafty repository."

step "Creating Python virtual environment..."
sudo -u crafty python3 -m venv /var/opt/minecraft/crafty/.venv || error_exit "Failed creating virtual environment."

step "Installing Crafty Python dependencies..."
sudo -u crafty /var/opt/minecraft/crafty/.venv/bin/pip install --no-cache-dir -r /var/opt/minecraft/crafty/crafty-4/requirements.txt \
|| error_exit "Failed to install Python dependencies."



step "Creating systemd service for Crafty..."

sudo tee /etc/systemd/system/crafty.service > /dev/null << 'EOF'
[Unit]
Description=Crafty Controller Service
After=network.target

[Service]
Type=simple
User=crafty
WorkingDirectory=/var/opt/minecraft/crafty/crafty-4
ExecStart=/var/opt/minecraft/crafty/.venv/bin/python3 /var/opt/minecraft/crafty/crafty-4/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

step "Creating systemd service for Playit.gg..."

sudo tee /etc/systemd/system/playit.service > /dev/null << 'EOF'
[Unit]
Description=Playit.gg Tunnel Agent
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/playit
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

step "Reloading systemd daemon..."
sudo systemctl daemon-reload || error_exit "Failed to reload systemd."

step "Enabling and starting Crafty..."
sudo systemctl enable --now crafty || error_exit "Failed to enable/start Crafty service."

step "Enabling and starting Playit..."
sudo systemctl enable --now playit || error_exit "Failed to enable/start Playit service."

step "All services installed and running!"
echo -e "${GREEN}Crafty is now running as a system service (crafty.service)${NC}"
echo -e "${GREEN}Playit.gg is now running as a system service (playit.service)${NC}"

echo -e "${BLUE}Check Crafty logs:   ${NC}sudo journalctl -u crafty -f"
echo -e "${BLUE}Check Playit logs:   ${NC}sudo journalctl -u playit -f"
echo -e "${BLUE}Stop Crafty:         ${NC}sudo systemctl stop crafty"
echo -e "${BLUE}Stop Playit:         ${NC}sudo systemctl stop playit"
