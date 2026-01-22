#!/bin/bash
# fix-line-endings.sh - Convert Windows CRLF to Unix LF line endings

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Fixing Line Endings (CRLF → LF)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if dos2unix is installed
if ! command -v dos2unix &> /dev/null; then
    echo -e "${YELLOW}Installing dos2unix...${NC}"
    sudo apt update && sudo apt install -y dos2unix
fi

# Find and fix all relevant files
echo -e "${BLUE}Converting files...${NC}"

# Fix Terraform files
find . -name "*.tf" -type f -exec dos2unix {} \; 2>/dev/null && echo -e "${GREEN}✓ Fixed .tf files${NC}"

# Fix Vagrantfile
find . -name "Vagrantfile" -type f -exec dos2unix {} \; 2>/dev/null && echo -e "${GREEN}✓ Fixed Vagrantfile${NC}"

# Fix template files
find . -name "*.tftpl" -type f -exec dos2unix {} \; 2>/dev/null && echo -e "${GREEN}✓ Fixed .tftpl files${NC}"

# Fix shell scripts
find . -name "*.sh" -type f -exec dos2unix {} \; 2>/dev/null && echo -e "${GREEN}✓ Fixed .sh files${NC}"

# Make scripts executable
echo ""
echo -e "${BLUE}Making scripts executable...${NC}"
chmod +x *.sh 2>/dev/null && echo -e "${GREEN}✓ Scripts are executable${NC}"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Line endings fixed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "You can now run: ./run-terraform.sh apply"
