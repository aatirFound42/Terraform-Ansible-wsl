#!/bin/bash
# quick-fix.sh - Quick fix for common WSL issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Quick Fix for WSL + Terraform + Vagrant${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 1. Install dos2unix if needed
if ! command -v dos2unix &> /dev/null; then
    echo -e "${YELLOW}Installing dos2unix...${NC}"
    sudo apt update && sudo apt install -y dos2unix
    echo -e "${GREEN}✓ dos2unix installed${NC}"
else
    echo -e "${GREEN}✓ dos2unix already installed${NC}"
fi

# 2. Fix line endings in all relevant files
echo ""
echo -e "${BLUE}Fixing line endings...${NC}"

# Current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fix all text files
find "$SCRIPT_DIR" -type f \( \
    -name "*.tf" -o \
    -name "*.sh" -o \
    -name "*.tftpl" -o \
    -name "Vagrantfile" -o \
    -name "Makefile" -o \
    -name "*.yml" -o \
    -name "*.yaml" -o \
    -name "*.ini" \
\) -exec dos2unix {} \; 2>/dev/null

echo -e "${GREEN}✓ Fixed line endings in all files${NC}"

# 3. Make scripts executable
echo ""
echo -e "${BLUE}Making scripts executable...${NC}"
find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;
echo -e "${GREEN}✓ Scripts are now executable${NC}"

# 4. Configure Git (if in a git repo)
if [ -d .git ]; then
    echo ""
    echo -e "${BLUE}Configuring Git...${NC}"
    git config core.autocrlf input
    git config core.eol lf
    git config core.filemode false
    echo -e "${GREEN}✓ Git configured for WSL${NC}"
fi

# 5. Create .gitattributes if it doesn't exist
if [ ! -f .gitattributes ]; then
    echo ""
    echo -e "${BLUE}Creating .gitattributes...${NC}"
    cat > .gitattributes << 'EOF'
* text=auto
*.sh text eol=lf
*.tf text eol=lf
*.tftpl text eol=lf
Vagrantfile text eol=lf
Makefile text eol=lf
EOF
    echo -e "${GREEN}✓ Created .gitattributes${NC}"
fi

# 6. Clean Terraform state if it exists (to force fresh start)
if [ -d terraform/.terraform ]; then
    echo ""
    echo -e "${YELLOW}Cleaning Terraform state...${NC}"
    cd terraform
    rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
    cd ..
    echo -e "${GREEN}✓ Terraform state cleaned${NC}"
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}All fixes applied successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "You can now run:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform apply -auto-approve"
echo ""
echo "Or use the wrapper script:"
echo "  ./run-terraform.sh apply"
