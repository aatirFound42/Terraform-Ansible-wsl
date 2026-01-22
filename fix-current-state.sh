#!/bin/bash
# fix-current-state.sh - Fix the current Vagrant/Terraform state issues

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
echo -e "${BLUE}Fixing Current Vagrant/Terraform State${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

cd "$TERRAFORM_DIR"

# 1. Kill any vagrant processes
echo -e "${YELLOW}Step 1: Killing Vagrant processes...${NC}"
pkill -f vagrant 2>/dev/null || true
pkill -f ruby 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓ Done${NC}"

# 2. Remove Vagrant locks
echo ""
echo -e "${YELLOW}Step 2: Removing Vagrant locks...${NC}"
find .vagrant -name "action_*" -type f -delete 2>/dev/null || true
find .vagrant -name "*.lock" -type f -delete 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"

# 3. Destroy any partial VMs
echo ""
echo -e "${YELLOW}Step 3: Destroying partial VMs...${NC}"
for i in {0..3}; do
    echo "  Checking node-$i..."
    vagrant destroy -f "node-$i" 2>/dev/null || echo "    No node-$i found"
done
echo -e "${GREEN}✓ Done${NC}"

# 4. Clean Terraform state
echo ""
echo -e "${YELLOW}Step 4: Cleaning Terraform state...${NC}"
rm -f terraform.tfstate terraform.tfstate.backup
echo -e "${GREEN}✓ Done${NC}"

# 5. Remove .vagrant directory
echo ""
echo -e "${YELLOW}Step 5: Removing .vagrant directory...${NC}"
rm -rf .vagrant
echo -e "${GREEN}✓ Done${NC}"

# 6. Prune Vagrant global status
echo ""
echo -e "${YELLOW}Step 6: Pruning Vagrant global status...${NC}"
vagrant global-status --prune
echo -e "${GREEN}✓ Done${NC}"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}State Fixed!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Now run the following to create VMs properly:"
echo ""
echo -e "${BLUE}  cd terraform${NC}"
echo -e "${BLUE}  terraform init${NC}"
echo -e "${BLUE}  terraform apply -auto-approve -parallelism=1${NC}"
echo ""
echo "Or use the wrapper script:"
echo -e "${BLUE}  ../run-terraform.sh apply${NC}"
