#!/bin/bash
# test-vms.sh - Test VM connectivity and readiness

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

# Default VM count
VM_COUNT=4

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Testing VM Connectivity${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Test SSH connectivity to each VM
echo -e "${BLUE}Testing SSH connectivity...${NC}"
SSH_KEY="$HOME/.vagrant.d/insecure_private_key"

if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found: $SSH_KEY${NC}"
    exit 1
fi

SUCCESS=0
FAILED=0

for i in $(seq 0 $((VM_COUNT - 1))); do
    IP="192.168.56.$((10 + i))"
    echo -n "Testing node-$i ($IP)... "
    
    if timeout 10 ssh -o StrictHostKeyChecking=no \
                       -o ConnectTimeout=5 \
                       -o BatchMode=yes \
                       -i "$SSH_KEY" \
                       vagrant@$IP \
                       "uname -n && uptime" > /tmp/vm_test_$i.txt 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
        cat /tmp/vm_test_$i.txt | sed 's/^/  /'
        ((SUCCESS++))
    else
        echo -e "${RED}✗ Failed${NC}"
        ((FAILED++))
    fi
    echo ""
done

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Success: $SUCCESS${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${BLUE}================================================${NC}"

# Test Ansible connectivity if inventory exists
if [ -f "$ANSIBLE_DIR/inventory.ini" ]; then
    echo ""
    echo -e "${BLUE}Testing Ansible connectivity...${NC}"
    
    if command -v ansible &> /dev/null; then
        ansible all -i "$ANSIBLE_DIR/inventory.ini" -m ping
    else
        echo -e "${YELLOW}Ansible not installed. Skipping Ansible test.${NC}"
        echo "Install with: sudo apt install ansible"
    fi
fi

# Show network info for each VM
echo ""
echo -e "${BLUE}Gathering network information...${NC}"

for i in $(seq 0 $((VM_COUNT - 1))); do
    IP="192.168.56.$((10 + i))"
    echo ""
    echo -e "${YELLOW}node-$i ($IP):${NC}"
    
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        -i "$SSH_KEY" \
        vagrant@$IP \
        "echo 'Hostname:' && hostname && echo '' && echo 'IP Addresses:' && ip -4 addr show | grep inet | awk '{print \$2}'" 2>/dev/null || echo -e "${RED}Failed to connect${NC}"
done

exit $FAILED
