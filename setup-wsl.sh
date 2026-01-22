#!/bin/bash
# setup-wsl.sh - Set up WSL environment for Terraform + Vagrant + VirtualBox

set -e

echo "================================================"
echo "WSL Environment Setup for Terraform + Vagrant"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    echo -e "${RED}Error: This script must be run in WSL${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running in WSL${NC}"

# Install Terraform if not present
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
else
    echo -e "${GREEN}✓ Terraform already installed${NC}"
fi

# Install Vagrant if not present
if ! command -v vagrant &> /dev/null; then
    echo "Installing Vagrant..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    sudo apt update && sudo apt install -y vagrant
else
    echo -e "${GREEN}✓ Vagrant already installed${NC}"
fi

# Set up VirtualBox integration
echo ""
echo "Setting up VirtualBox integration..."
echo -e "${YELLOW}Note: VirtualBox must be installed on Windows${NC}"

# Get Windows username
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
echo "Windows Username: $WIN_USER"

# Set environment variables for VirtualBox
VBOX_MSI_INSTALL_PATH="/mnt/c/Program Files/Oracle/VirtualBox"
VBOX_INSTALL_PATH=$(wslpath -u "C:\\Program Files\\Oracle\\VirtualBox")

# Check if VirtualBox is installed on Windows
if [ ! -d "$VBOX_INSTALL_PATH" ]; then
    echo -e "${RED}Error: VirtualBox not found at: $VBOX_INSTALL_PATH${NC}"
    echo "Please install VirtualBox on Windows first"
    exit 1
fi

echo -e "${GREEN}✓ VirtualBox found at: $VBOX_INSTALL_PATH${NC}"

# Create/update .bashrc with required environment variables
BASHRC_ADDITIONS="
# Vagrant + VirtualBox WSL Integration
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=\"1\"
export PATH=\"\$PATH:$VBOX_INSTALL_PATH\"
export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=\"/mnt/c/Users/$WIN_USER\"
"

if ! grep -q "VAGRANT_WSL_ENABLE_WINDOWS_ACCESS" ~/.bashrc; then
    echo "$BASHRC_ADDITIONS" >> ~/.bashrc
    echo -e "${GREEN}✓ Added environment variables to ~/.bashrc${NC}"
else
    echo -e "${YELLOW}⚠ Environment variables already in ~/.bashrc${NC}"
fi

# Source the updated bashrc for current session
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:$VBOX_INSTALL_PATH"
export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/c/Users/$WIN_USER"

# Create shared directory for Vagrant
VAGRANT_HOME_WSL="$HOME/.vagrant.d"
VAGRANT_HOME_WIN="/mnt/c/Users/$WIN_USER/.vagrant.d"

mkdir -p "$VAGRANT_HOME_WSL"

# Link to Windows .vagrant.d if it exists
if [ -d "$VAGRANT_HOME_WIN" ] && [ ! -L "$VAGRANT_HOME_WSL" ]; then
    echo "Linking WSL Vagrant home to Windows Vagrant home..."
    rm -rf "$VAGRANT_HOME_WSL"
    ln -s "$VAGRANT_HOME_WIN" "$VAGRANT_HOME_WSL"
    echo -e "${GREEN}✓ Linked Vagrant directories${NC}"
fi

# Install required Vagrant plugins
echo ""
echo "Installing Vagrant plugins..."
vagrant plugin install vagrant-vbguest 2>/dev/null || echo -e "${YELLOW}⚠ Plugin may already be installed${NC}"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Please run: source ~/.bashrc"
echo "Or restart your WSL terminal"
echo ""
echo "Then you can use: ./run-terraform.sh"
