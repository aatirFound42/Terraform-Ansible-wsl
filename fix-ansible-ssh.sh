#!/bin/bash
# fix-ansible-ssh.sh - Fix SSH connectivity issues for Ansible

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Fixing SSH connectivity issues...${NC}"

# Fix 1: Fix SSH key permissions
echo -e "${YELLOW}1. Fixing SSH key permissions...${NC}"

# Create a clean copy of the key in WSL filesystem
mkdir -p "$HOME/ssh-keys"

if [ -f "$HOME/.vagrant.d/insecure_private_key" ]; then
    cp "$HOME/.vagrant.d/insecure_private_key" "$HOME/ssh-keys/insecure_private_key"
    chmod 600 "$HOME/ssh-keys/insecure_private_key"
    echo -e "${GREEN}✓ Key copied to $HOME/ssh-keys/insecure_private_key with correct permissions${NC}"
else
    echo -e "${RED}Error: Vagrant key not found at $HOME/.vagrant.d/insecure_private_key${NC}"
    exit 1
fi

# Fix 2: Clear old SSH host keys
echo -e "${YELLOW}2. Clearing old SSH host keys...${NC}"

for i in {10..14}; do
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.56.$i" 2>/dev/null || true
done

echo -e "${GREEN}✓ Old host keys cleared${NC}"

# Fix 3: Fix inventory file format
echo -e "${YELLOW}3. Fixing inventory file format...${NC}"

INVENTORY_FILE="$HOME/terravag/ansible/inventory.ini"

if [ -f "$INVENTORY_FILE" ]; then
    # Check if file has proper newlines
    if grep -q "node-0.*node-1" "$INVENTORY_FILE"; then
        echo -e "${YELLOW}Inventory file has formatting issues, regenerating...${NC}"
        
        # Backup old file
        cp "$INVENTORY_FILE" "$INVENTORY_FILE.backup"
        
        # Create properly formatted inventory
        cat > "$INVENTORY_FILE" << 'EOF'
# Ansible Inventory for Vagrant VMs
[nodes]
node-0 ansible_host=192.168.56.10 ansible_user=vagrant ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
node-1 ansible_host=192.168.56.11 ansible_user=vagrant ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
node-2 ansible_host=192.168.56.12 ansible_user=vagrant ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
node-3 ansible_host=192.168.56.13 ansible_user=vagrant ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
node-4 ansible_host=192.168.56.14 ansible_user=vagrant ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[nodes:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
        
        echo -e "${GREEN}✓ Inventory file regenerated${NC}"
    else
        echo -e "${GREEN}✓ Inventory file format looks OK${NC}"
        
        # Update to use the new key path
        sed -i 's|~/.vagrant.d/insecure_private_key|~/ssh-keys/insecure_private_key|g' "$INVENTORY_FILE"
        
        # Add UserKnownHostsFile if not present
        if ! grep -q "UserKnownHostsFile" "$INVENTORY_FILE"; then
            sed -i "s/StrictHostKeyChecking=no'/StrictHostKeyChecking=no -o UserKnownHostsFile=\/dev\/null'/g" "$INVENTORY_FILE"
        fi
    fi
else
    echo -e "${RED}Error: Inventory file not found: $INVENTORY_FILE${NC}"
    exit 1
fi

# Fix 4: Test SSH connectivity
echo -e "${YELLOW}4. Testing SSH connectivity...${NC}"

SUCCESS_COUNT=0
TOTAL_COUNT=5

for i in {0..4}; do
    IP="192.168.56.$((10 + i))"
    echo -n "Testing node-$i ($IP)... "
    
    if ssh -i "$HOME/ssh-keys/insecure_private_key" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o ConnectTimeout=5 \
           -o LogLevel=ERROR \
           vagrant@$IP "echo 'OK'" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
done

echo ""
echo -e "${BLUE}SSH Test Results: ${GREEN}$SUCCESS_COUNT${NC}/${TOTAL_COUNT} nodes accessible"

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
    echo -e "${GREEN}All nodes are accessible!${NC}"
    echo ""
    echo -e "${BLUE}Now you can run Ansible:${NC}"
    echo -e "  cd ~/terravag/ansible"
    echo -e "  ../run-ansible.sh ping"
    echo -e "  ../run-ansible.sh playbook playbook.yml"
else
    echo -e "${YELLOW}Some nodes are not accessible yet.${NC}"
    echo -e "Wait a few seconds for VMs to finish booting, then run this script again."
fi
