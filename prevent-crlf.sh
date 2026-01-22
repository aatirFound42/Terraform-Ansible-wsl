#!/bin/bash
# prevent-crlf.sh - Configure Git and environment to prevent CRLF issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Preventing Future CRLF Issues${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Configure Git to use LF line endings
echo -e "${BLUE}Configuring Git...${NC}"

# Set core.autocrlf to input (converts CRLF to LF on commit)
git config --global core.autocrlf input
echo -e "${GREEN}✓ Set core.autocrlf to input${NC}"

# Set core.eol to lf (checkout with LF)
git config --global core.eol lf
echo -e "${GREEN}✓ Set core.eol to lf${NC}"

# Create .gitattributes file if it doesn't exist
if [ ! -f .gitattributes ]; then
    echo -e "${BLUE}Creating .gitattributes...${NC}"
    cat > .gitattributes << 'EOF'
# Set default behavior to automatically normalize line endings
* text=auto

# Force LF for specific file types
*.sh text eol=lf
*.tf text eol=lf
*.tftpl text eol=lf
Vagrantfile text eol=lf
Makefile text eol=lf

# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.mov binary
*.mp4 binary
*.mp3 binary
*.flv binary
*.fla binary
*.swf binary
*.gz binary
*.zip binary
*.7z binary
*.ttf binary
*.eot binary
*.woff binary
*.woff2 binary
EOF
    echo -e "${GREEN}✓ Created .gitattributes${NC}"
else
    echo -e "${YELLOW}⚠ .gitattributes already exists${NC}"
fi

# Create .editorconfig file if it doesn't exist
if [ ! -f .editorconfig ]; then
    echo -e "${BLUE}Creating .editorconfig...${NC}"
    cat > .editorconfig << 'EOF'
# EditorConfig is awesome: https://EditorConfig.org

root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.{sh,tf,tftpl}]
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab

[Vagrantfile]
indent_style = space
indent_size = 2
EOF
    echo -e "${GREEN}✓ Created .editorconfig${NC}"
else
    echo -e "${YELLOW}⚠ .editorconfig already exists${NC}"
fi

# Add WSL-specific Git configuration
echo -e "${BLUE}Adding WSL-specific Git config...${NC}"

# Disable filemode checking (Windows filesystem doesn't preserve execute bit reliably)
git config --global core.filemode false
echo -e "${GREEN}✓ Disabled filemode checking${NC}"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Git is now configured to:"
echo "  • Convert CRLF to LF on commit (autocrlf=input)"
echo "  • Checkout files with LF (eol=lf)"
echo "  • Use .gitattributes for file-specific rules"
echo ""
echo "Next steps:"
echo "  1. Run: ./fix-line-endings.sh"
echo "  2. Run: ./run-terraform.sh apply"
