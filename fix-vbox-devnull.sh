#!/bin/bash
# fix-vbox-devnull.sh - Quick fix for VirtualBox /dev/null error in WSL

set -e

echo "=========================================="
echo "VirtualBox /dev/null Error Fix"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get Windows username
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')

# VirtualBox path
VBOX_MSI_INSTALL_PATH="/mnt/c/Program Files/Oracle/VirtualBox"

echo -e "${BLUE}Setting environment variables...${NC}"
echo ""

# Check if already set
if grep -q "VBOX_MSI_INSTALL_PATH" ~/.bashrc; then
    echo -e "${YELLOW}⚠ VBOX_MSI_INSTALL_PATH already set in ~/.bashrc${NC}"
    echo ""
    echo "Current value:"
    grep "VBOX_MSI_INSTALL_PATH" ~/.bashrc
    echo ""
    echo -e "${YELLOW}Re-run anyway? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    # Remove old entry
    sed -i '/VBOX_MSI_INSTALL_PATH/d' ~/.bashrc
fi

# Add to .bashrc
echo "export VBOX_MSI_INSTALL_PATH=\"$VBOX_MSI_INSTALL_PATH\"" >> ~/.bashrc

echo -e "${GREEN}✓ Added VBOX_MSI_INSTALL_PATH to ~/.bashrc${NC}"
echo ""

# Export for current session
export VBOX_MSI_INSTALL_PATH="$VBOX_MSI_INSTALL_PATH"
echo -e "${GREEN}✓ Exported for current session${NC}"
echo ""

echo -e "${BLUE}Verification:${NC}"
echo "  VBOX_MSI_INSTALL_PATH = $VBOX_MSI_INSTALL_PATH"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run: ${GREEN}source ~/.bashrc${NC}"
echo "  2. Clean up: ${GREEN}./run-terraform.sh destroy${NC}"
echo "  3. Retry: ${GREEN}./run-terraform.sh apply${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "Fix Applied Successfully!"
echo -e "==========================================${NC}"
