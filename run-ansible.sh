#!/bin/bash
# run-ansible.sh - Run Ansible playbooks against VMs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.ini"

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}Error: Ansible is not installed${NC}"
    echo "Install with: sudo apt update && sudo apt install -y ansible"
    exit 1
fi

# Check if inventory exists
if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}Error: Inventory file not found: $INVENTORY${NC}"
    echo "Please run Terraform first: ./run-terraform.sh apply"
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 [ping|facts|command|playbook] [args...]"
    echo ""
    echo "Commands:"
    echo "  ping              - Test connectivity to all nodes"
    echo "  facts             - Gather facts from all nodes"
    echo "  command 'CMD'     - Run command on all nodes"
    echo "  playbook FILE.yml - Run a playbook"
    echo "  shell             - Interactive shell on all nodes"
    exit 1
}

COMMAND="${1:-ping}"

case $COMMAND in
    ping)
        echo -e "${BLUE}Testing Ansible connectivity...${NC}"
        ansible all -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ All nodes responding${NC}"
        ;;
    
    facts)
        echo -e "${BLUE}Gathering facts from all nodes...${NC}"
        ansible all -i "$INVENTORY" -m setup
        ;;
    
    command)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No command specified${NC}"
            usage
        fi
        
        CMD="$2"
        echo -e "${BLUE}Running command on all nodes: ${YELLOW}$CMD${NC}"
        ansible all -i "$INVENTORY" -a "$CMD"
        ;;
    
    playbook)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No playbook specified${NC}"
            usage
        fi
        
        PLAYBOOK="$2"
        if [ ! -f "$PLAYBOOK" ]; then
            # Try in ansible directory
            PLAYBOOK="$ANSIBLE_DIR/$2"
            if [ ! -f "$PLAYBOOK" ]; then
                echo -e "${RED}Error: Playbook not found: $2${NC}"
                exit 1
            fi
        fi
        
        echo -e "${BLUE}Running playbook: ${YELLOW}$PLAYBOOK${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
        ;;
    
    shell)
        echo -e "${BLUE}Starting interactive shell on all nodes...${NC}"
        echo -e "${YELLOW}Type your commands (Ctrl+D to exit):${NC}"
        ansible all -i "$INVENTORY" -m shell -a 'bash'
        ;;
    
    *)
        usage
        ;;
esac
