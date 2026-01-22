#!/bin/bash
# cleanup-vagrant.sh - Clean up Vagrant state and locks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Cleaning Up Vagrant State${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

cd "$TERRAFORM_DIR"

# 1. Kill any running vagrant or ruby processes
echo -e "${YELLOW}Checking for running Vagrant processes...${NC}"
if pgrep -f "vagrant" > /dev/null; then
    echo -e "${YELLOW}Found running Vagrant processes. Killing them...${NC}"
    pkill -f "vagrant" 2>/dev/null || true
    sleep 2
    echo -e "${GREEN}✓ Processes killed${NC}"
else
    echo -e "${GREEN}✓ No running Vagrant processes${NC}"
fi

# 2. Remove Vagrant locks
echo ""
echo -e "${BLUE}Removing Vagrant locks...${NC}"
if [ -d .vagrant ]; then
    find .vagrant -name "action_*" -type f -delete 2>/dev/null && echo -e "${GREEN}✓ Removed action locks${NC}"
    find .vagrant -name "*.lock" -type f -delete 2>/dev/null && echo -e "${GREEN}✓ Removed lock files${NC}"
else
    echo -e "${YELLOW}⚠ No .vagrant directory found${NC}"
fi

# 3. Get list of VMs from Vagrant global status
echo ""
echo -e "${BLUE}Checking Vagrant global status...${NC}"
vagrant global-status --prune

# 4. Attempt to destroy any existing VMs
echo ""
echo -e "${YELLOW}Attempting to destroy existing VMs...${NC}"
for i in {0..10}; do
    if vagrant status "node-$i" 2>/dev/null | grep -q "running\|saved\|poweroff"; then
        echo "Destroying node-$i..."
        vagrant destroy -f "node-$i" 2>/dev/null || echo "  Could not destroy node-$i"
    fi
done

# 5. Remove .vagrant directory completely
echo ""
echo -e "${YELLOW}Do you want to remove the entire .vagrant directory? (y/N)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -rf .vagrant
    echo -e "${GREEN}✓ .vagrant directory removed${NC}"
else
    echo -e "${YELLOW}⚠ Keeping .vagrant directory${NC}"
fi

# 6. Clean Terraform state
echo ""
echo -e "${YELLOW}Do you want to clean Terraform state? (y/N)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
    echo -e "${GREEN}✓ Terraform state cleaned${NC}"
else
    echo -e "${YELLOW}⚠ Keeping Terraform state${NC}"
fi

# 7. Check VirtualBox VMs
echo ""
echo -e "${BLUE}Checking VirtualBox VMs...${NC}"
if command -v VBoxManage &> /dev/null; then
    VBoxManage list vms | grep -i "testnode\|node-" || echo "No matching VMs found"
elif [ -f "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" ]; then
    "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list vms | grep -i "testnode\|node-" || echo "No matching VMs found"
else
    echo -e "${YELLOW}⚠ VBoxManage not found${NC}"
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "You can now run:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform apply -auto-approve -parallelism=1"
echo ""
echo "Or use the wrapper:"
echo "  ../run-terraform.sh apply"
