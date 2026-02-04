#!/bin/bash
# fix-wsl-virtualbox.sh - Fix VirtualBox /dev/null error in WSL
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Fixing WSL/VirtualBox Serial Port Issue${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Step 1: Destroy any existing VMs
echo -e "${YELLOW}Step 1: Cleaning up existing VMs...${NC}"
cd "$TERRAFORM_DIR"

# Destroy via Terraform
terraform destroy -auto-approve 2>/dev/null || true

# Also clean via Vagrant directly
for i in {0..7}; do
    vagrant destroy -f "node-$i" 2>/dev/null || true
done

# Clean Vagrant global state
vagrant global-status --prune

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 2: Check if Vagrantfile exists and back it up
echo -e "${YELLOW}Step 2: Updating Vagrantfile...${NC}"

if [ -f "$TERRAFORM_DIR/Vagrantfile" ]; then
    BACKUP_NAME="Vagrantfile.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${BLUE}Backing up existing Vagrantfile to $BACKUP_NAME${NC}"
    cp "$TERRAFORM_DIR/Vagrantfile" "$TERRAFORM_DIR/$BACKUP_NAME"
fi

# Copy the fixed Vagrantfile
cat > "$TERRAFORM_DIR/Vagrantfile" << 'VAGRANTFILE_CONTENT'
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Read environment variables
VM_COUNT = ENV['VAGRANT_VM_COUNT'] ? ENV['VAGRANT_VM_COUNT'].to_i : 8
VM_NAME = ENV['VAGRANT_VM_NAME'] || "testnode"
CPUS = ENV['VAGRANT_CPUS'] ? ENV['VAGRANT_CPUS'].to_i : 1
MEMORY = ENV['VAGRANT_MEMORY'] ? ENV['VAGRANT_MEMORY'].to_i : 2048
BOX = ENV['VAGRANT_BOX'] || "ubuntu/jammy64"

Vagrant.configure("2") do |config|
  (0...VM_COUNT).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.box = BOX
      node.vm.hostname = "#{VM_NAME}-#{i}"
      
      # Private network for cluster communication
      node.vm.network "private_network", ip: "192.168.56.#{10 + i}"
      
      node.vm.provider "virtualbox" do |vb|
        vb.name = "#{VM_NAME}-#{i}"
        vb.cpus = CPUS
        vb.memory = MEMORY
        
        # **CRITICAL FIX FOR WSL**: Disable serial port to avoid /dev/null error
        vb.customize ["modifyvm", :id, "--uart1", "off"]
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
        
        # Additional recommended settings for stability
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        
        # Improve performance
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
        vb.customize ["modifyvm", :id, "--audio", "none"]
        vb.customize ["modifyvm", :id, "--usb", "off"]
        vb.customize ["modifyvm", :id, "--vrde", "off"]
      end
    end
  end
end
VAGRANTFILE_CONTENT

echo -e "${GREEN}✓ Vagrantfile updated with WSL fixes${NC}"
echo ""

# Step 3: Verify VirtualBox is accessible
echo -e "${YELLOW}Step 3: Verifying VirtualBox...${NC}"

VBOX_PATH="/mnt/c/Program Files/Oracle/VirtualBox"
if [ -x "$VBOX_PATH/VBoxManage.exe" ]; then
    VBOX_VERSION=$("$VBOX_PATH/VBoxManage.exe" --version 2>/dev/null | tr -d '\r')
    echo -e "${GREEN}✓ VirtualBox found: $VBOX_VERSION${NC}"
else
    echo -e "${RED}✗ VirtualBox not found at: $VBOX_PATH${NC}"
    echo -e "${YELLOW}Please verify VirtualBox is installed on Windows${NC}"
    exit 1
fi

echo ""

# Step 4: Test with a single VM
echo -e "${YELLOW}Step 4: Testing with a single VM...${NC}"
echo -e "${BLUE}This will create node-0 as a test${NC}"
echo ""

cd "$TERRAFORM_DIR"

# Test with just node-0
export VAGRANT_VM_COUNT=8
export VAGRANT_VM_NAME=testnode
export VAGRANT_CPUS=1
export VAGRANT_MEMORY=2048
export VAGRANT_BOX=ubuntu/jammy64

echo -e "${BLUE}Creating test VM (node-0)...${NC}"
if vagrant up node-0 --provider=virtualbox; then
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}✓ SUCCESS! Test VM created successfully${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}The fix worked! You can now:${NC}"
    echo ""
    echo -e "1. ${GREEN}Destroy the test VM:${NC}"
    echo -e "   cd $TERRAFORM_DIR && vagrant destroy -f node-0"
    echo ""
    echo -e "2. ${GREEN}Deploy all VMs:${NC}"
    echo -e "   ./run-terraform.sh apply"
    echo ""
else
    echo ""
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}✗ Test VM creation failed${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Additional troubleshooting steps:${NC}"
    echo ""
    echo -e "1. ${BLUE}Restart Windows${NC} (VirtualBox may need reinitialization)"
    echo ""
    echo -e "2. ${BLUE}Verify Hyper-V is disabled:${NC}"
    echo -e "   Run in PowerShell (Admin):"
    echo -e "   ${GREEN}Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All${NC}"
    echo ""
    echo -e "3. ${BLUE}Check VirtualBox VMs:${NC}"
    echo -e "   ${GREEN}VBoxManage.exe list vms${NC}"
    echo ""
    echo -e "4. ${BLUE}Try running with debug output:${NC}"
    echo -e "   ${GREEN}cd $TERRAFORM_DIR && vagrant up node-0 --debug${NC}"
    echo ""
    exit 1
fi
