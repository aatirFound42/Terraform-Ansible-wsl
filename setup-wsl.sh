#!/bin/bash
# setup-wsl.sh - Set up WSL environment for Terraform + Vagrant + VirtualBox
# Enhanced version with validation and better error handling

set -e

echo "================================================"
echo "WSL Environment Setup for Terraform + Vagrant"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    log_error "This script must be run in WSL"
    exit 1
fi

log_success "Running in WSL"

# Get WSL version
WSL_VERSION=$(wsl.exe -l -v 2>/dev/null | grep -i "$(hostname)" | awk '{print $3}' || echo "Unknown")
log_info "WSL Version: $WSL_VERSION"

# ------------------------------------------------
# System Update
# ------------------------------------------------
log_info "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# ------------------------------------------------
# Add HashiCorp apt repo (safe to run multiple times)
# ------------------------------------------------
log_info "Setting up HashiCorp repository..."

if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
    log_info "Adding HashiCorp GPG key..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    log_success "HashiCorp GPG key added"
else
    log_success "HashiCorp GPG key already exists"
fi

if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
    log_info "Adding HashiCorp apt repository..."
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    log_success "HashiCorp apt repository added"
else
    log_success "HashiCorp apt repository already exists"
fi

sudo apt update

# ------------------------------------------------
# Install Terraform
# ------------------------------------------------
if ! command -v terraform &> /dev/null; then
    log_info "Installing Terraform..."
    sudo apt install -y terraform
    log_success "Terraform installed"
else
    TERRAFORM_VERSION=$(terraform version | head -n1)
    log_success "Terraform already installed: $TERRAFORM_VERSION"
fi

# ------------------------------------------------
# Install Vagrant
# ------------------------------------------------
if ! command -v vagrant &> /dev/null; then
    log_info "Installing Vagrant..."
    sudo apt install -y vagrant
    log_success "Vagrant installed"
else
    VAGRANT_VERSION=$(vagrant version | head -n1)
    log_success "Vagrant already installed: $VAGRANT_VERSION"
fi

# ------------------------------------------------
# Install Ansible
# ------------------------------------------------
if ! command -v ansible &> /dev/null; then
    log_info "Installing Ansible..."
    sudo apt install -y ansible
    log_success "Ansible installed"
else
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    log_success "Ansible already installed: $ANSIBLE_VERSION"
fi

# Common Ansible dependencies
log_info "Installing Ansible dependencies..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    sshpass \
    rsync \
    git

log_success "Ansible dependencies installed"

# Common Ansible collections
log_info "Installing Ansible collections..."
ansible-galaxy collection install \
    community.general \
    ansible.posix \
    --force 2>&1 | grep -v "skipping" || true

log_success "Ansible collections installed"

# ------------------------------------------------
# VirtualBox Integration Setup
# ------------------------------------------------
echo ""
log_info "Setting up VirtualBox integration..."
log_warning "VirtualBox must be installed on Windows"

# Get Windows username
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
log_info "Windows Username: $WIN_USER"

# Set environment variables for VirtualBox
VBOX_MSI_INSTALL_PATH="/mnt/c/Program Files/Oracle/VirtualBox"
VBOX_INSTALL_PATH=$(wslpath -u "C:\\Program Files\\Oracle\\VirtualBox")

# Check if VirtualBox is installed on Windows
if [ ! -d "$VBOX_INSTALL_PATH" ]; then
    log_error "VirtualBox not found at: $VBOX_INSTALL_PATH"
    log_error "Please install VirtualBox on Windows first"
    echo ""
    echo "Download from: https://www.virtualbox.org/wiki/Downloads"
    exit 1
fi

log_success "VirtualBox found at: $VBOX_INSTALL_PATH"

# Verify VirtualBox is working
log_info "Verifying VirtualBox installation..."
if "$VBOX_INSTALL_PATH/VBoxManage.exe" --version &> /dev/null; then
    VBOX_VERSION=$("$VBOX_INSTALL_PATH/VBoxManage.exe" --version 2>/dev/null | tr -d '\r')
    log_success "VirtualBox version: $VBOX_VERSION"
else
    log_warning "Could not execute VBoxManage.exe - may need to restart Windows"
fi

# Check for Hyper-V conflict
log_info "Checking for Hyper-V conflicts..."
if powershell.exe -Command "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State" 2>/dev/null | grep -q "Enabled"; then
    log_warning "Hyper-V is enabled - this may conflict with VirtualBox"
    log_warning "Consider disabling Hyper-V if you encounter issues"
    log_warning "Run in PowerShell (Admin): Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All"
else
    log_success "Hyper-V is not enabled (good for VirtualBox)"
fi

# ------------------------------------------------
# Configure Environment Variables
# ------------------------------------------------
log_info "Configuring environment variables..."

# Create/update .bashrc with required environment variables
BASHRC_ADDITIONS="
# ============================================
# Vagrant + VirtualBox WSL Integration
# ============================================
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=\"1\"
export PATH=\"\$PATH:$VBOX_INSTALL_PATH\"
export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=\"/mnt/c/Users/$WIN_USER\"
export VBOX_MSI_INSTALL_PATH=\"$VBOX_MSI_INSTALL_PATH\"

# VirtualBox command aliases (for convenience)
alias VBoxManage='$VBOX_INSTALL_PATH/VBoxManage.exe'
alias vboxmanage='$VBOX_INSTALL_PATH/VBoxManage.exe'

# Optional: Increase Vagrant timeout for slow networks
# export VAGRANT_DEFAULT_PROVIDER=\"virtualbox\"
# export VAGRANT_CHECKPOINT_DISABLE=\"1\"
"

if ! grep -q "VAGRANT_WSL_ENABLE_WINDOWS_ACCESS" ~/.bashrc; then
    echo "$BASHRC_ADDITIONS" >> ~/.bashrc
    log_success "Added environment variables to ~/.bashrc"
else
    log_warning "Environment variables already in ~/.bashrc"
    log_info "To update, remove the old section and re-run this script"
fi

# Source the updated bashrc for current session
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:$VBOX_INSTALL_PATH"
export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/c/Users/$WIN_USER"
export VBOX_MSI_INSTALL_PATH="$VBOX_MSI_INSTALL_PATH"

# ------------------------------------------------
# Configure Vagrant Directories
# ------------------------------------------------
log_info "Configuring Vagrant directories..."

VAGRANT_HOME_WSL="$HOME/.vagrant.d"
VAGRANT_HOME_WIN="/mnt/c/Users/$WIN_USER/.vagrant.d"

# Create Windows Vagrant directory if it doesn't exist
if [ ! -d "$VAGRANT_HOME_WIN" ]; then
    log_info "Creating Windows Vagrant directory..."
    mkdir -p "$VAGRANT_HOME_WIN"
fi

# Link to Windows .vagrant.d
if [ -L "$VAGRANT_HOME_WSL" ]; then
    log_success "Vagrant directories already linked"
elif [ -d "$VAGRANT_HOME_WSL" ]; then
    log_info "Backing up existing WSL Vagrant directory..."
    mv "$VAGRANT_HOME_WSL" "${VAGRANT_HOME_WSL}.backup.$(date +%Y%m%d_%H%M%S)"
    ln -s "$VAGRANT_HOME_WIN" "$VAGRANT_HOME_WSL"
    log_success "Linked Vagrant directories (backup created)"
else
    ln -s "$VAGRANT_HOME_WIN" "$VAGRANT_HOME_WSL"
    log_success "Linked Vagrant directories"
fi

# ------------------------------------------------
# Install Vagrant Plugins
# ------------------------------------------------
echo ""
log_info "Installing Vagrant plugins..."

# Check and install vagrant-vbguest
if vagrant plugin list 2>/dev/null | grep -q "vagrant-vbguest"; then
    log_success "vagrant-vbguest already installed"
else
    log_info "Installing vagrant-vbguest..."
    vagrant plugin install vagrant-vbguest || log_warning "Failed to install vagrant-vbguest"
fi

# Optional but useful plugins
OPTIONAL_PLUGINS=("vagrant-disksize" "vagrant-hostmanager")
for plugin in "${OPTIONAL_PLUGINS[@]}"; do
    if vagrant plugin list 2>/dev/null | grep -q "$plugin"; then
        log_success "$plugin already installed"
    else
        log_info "Installing $plugin (optional)..."
        vagrant plugin install "$plugin" 2>/dev/null || log_warning "Failed to install $plugin (optional)"
    fi
done

# ------------------------------------------------
# Network Verification
# ------------------------------------------------
echo ""
log_info "Verifying network connectivity..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    log_success "Network connectivity OK"
else
    log_warning "Network connectivity issue detected"
    log_warning "This may affect downloading Vagrant boxes"
fi

# ------------------------------------------------
# Create Test/Example Files
# ------------------------------------------------
log_info "Creating example directory structure..."

EXAMPLE_DIR="$HOME/terraform-vagrant-examples"
if [ ! -d "$EXAMPLE_DIR" ]; then
    mkdir -p "$EXAMPLE_DIR"
    
    # Create a simple Vagrantfile example
    cat > "$EXAMPLE_DIR/Vagrantfile.example" << 'EOF'
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end
  
  config.vm.network "private_network", ip: "192.168.56.10"
  
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
  end
end
EOF

    # Create a simple Ansible playbook example
    cat > "$EXAMPLE_DIR/playbook.example.yml" << 'EOF'
---
- name: Basic setup
  hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
    
    - name: Install basic packages
      apt:
        name:
          - vim
          - curl
          - git
        state: present
EOF

    log_success "Example files created in: $EXAMPLE_DIR"
fi

# ------------------------------------------------
# Validation Tests
# ------------------------------------------------
echo ""
log_info "Running validation tests..."

# Test Terraform
if terraform version &> /dev/null; then
    log_success "Terraform: OK"
else
    log_error "Terraform: FAILED"
fi

# Test Vagrant
if vagrant version &> /dev/null; then
    log_success "Vagrant: OK"
else
    log_error "Vagrant: FAILED"
fi

# Test Ansible
if ansible --version &> /dev/null; then
    log_success "Ansible: OK"
else
    log_error "Ansible: FAILED"
fi

# Test VirtualBox access
if "$VBOX_INSTALL_PATH/VBoxManage.exe" list vms &> /dev/null; then
    log_success "VirtualBox: OK"
else
    log_warning "VirtualBox: Cannot list VMs (may need Windows restart)"
fi

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Installed Versions:${NC}"
echo "  • Terraform: $(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4 || echo 'unknown')"
echo "  • Vagrant: $(vagrant version 2>/dev/null | head -n1 | awk '{print $3}' || echo 'unknown')"
echo "  • Ansible: $(ansible --version 2>/dev/null | head -n1 | awk '{print $2}' || echo 'unknown')"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run: ${GREEN}source ~/.bashrc${NC}"
echo "     Or restart your WSL terminal"
echo ""
echo "  2. Test the setup with:"
echo "     ${GREEN}cd $EXAMPLE_DIR${NC}"
echo "     ${GREEN}cp Vagrantfile.example Vagrantfile${NC}"
echo "     ${GREEN}vagrant up${NC}"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  • If Vagrant fails, restart Windows to ensure VirtualBox is fully initialized"
echo "  • Check VirtualBox VMs: ${GREEN}VBoxManage.exe list vms${NC}"
echo "  • View Vagrant logs: ${GREEN}vagrant up --debug${NC}"
echo ""
echo -e "${BLUE}Example files location:${NC}"
echo "  $EXAMPLE_DIR"
echo ""
echo -e "${GREEN}Happy provisioning!${NC}"
