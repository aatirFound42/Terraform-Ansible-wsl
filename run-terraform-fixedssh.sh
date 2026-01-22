#!/bin/bash
# run-terraform.sh - Run Terraform with Vagrant on WSL

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    echo -e "${RED}Error: This script must be run in WSL${NC}"
    exit 1
fi

# Check required environment variables
if [ -z "$VAGRANT_WSL_ENABLE_WINDOWS_ACCESS" ]; then
    echo -e "${RED}Error: WSL environment not configured${NC}"
    echo "Please run: ./setup-wsl.sh"
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 [init|plan|apply|destroy|status|ssh|clean]"
    echo ""
    echo "Commands:"
    echo "  init     - Initialize Terraform"
    echo "  plan     - Show Terraform execution plan"
    echo "  apply    - Create VMs with Terraform"
    echo "  destroy  - Destroy all VMs"
    echo "  status   - Show Vagrant VM status"
    echo "  ssh N    - SSH into VM number N (0-based)"
    echo "  clean    - Clean all Terraform and Vagrant files"
    exit 1
}

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

# Parse command
COMMAND="${1:-apply}"

case $COMMAND in
    init)
        echo -e "${BLUE}Initializing Terraform...${NC}"
        cd "$TERRAFORM_DIR"
        terraform init
        echo -e "${GREEN}✓ Terraform initialized${NC}"
        ;;

    plan)
        echo -e "${BLUE}Planning Terraform changes...${NC}"
        cd "$TERRAFORM_DIR"
        terraform plan
        ;;

    apply)
        echo -e "${BLUE}Creating VMs with Terraform...${NC}"
        cd "$TERRAFORM_DIR"

        # Check if already initialized
        if [ ! -d ".terraform" ]; then
            echo -e "${YELLOW}Terraform not initialized. Running init...${NC}"
            terraform init
        fi

        # Clean up any stale Vagrant locks
        echo -e "${BLUE}Cleaning up stale locks...${NC}"
        find .vagrant/machines -name "action_*" -type f -delete 2>/dev/null || true

        # Apply with limited parallelism to avoid Vagrant conflicts
        echo -e "${BLUE}Creating VMs sequentially to avoid conflicts...${NC}"
        terraform apply -auto-approve -parallelism=1

        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}VMs Created Successfully!${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""

        # Wait for VMs to be fully ready
        echo -e "${BLUE}Waiting for VMs to be fully ready...${NC}"
        sleep 30

        # Show VM status
        echo ""
        echo -e "${BLUE}VM Status:${NC}"
        cd "$TERRAFORM_DIR"
        vagrant global-status

        # Show Ansible inventory
        if [ -f "$SCRIPT_DIR/ansible/inventory.ini" ]; then
            echo ""
            echo -e "${BLUE}Ansible Inventory:${NC}"
            cat "$SCRIPT_DIR/ansible/inventory.ini"
        fi

        # Test connectivity
        echo ""
        echo -e "${BLUE}Testing SSH connectivity...${NC}"
        VM_COUNT=$(terraform output -json 2>/dev/null | jq -r '.vm_count.value // 4')

        for i in $(seq 0 $((VM_COUNT - 1))); do
            IP="192.168.56.$((10 + i))"
            echo -n "Testing node-$i ($IP)... "
            if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.vagrant.d/insecure_private_key vagrant@$IP "echo 'OK'" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}⚠ Not ready yet${NC}"
            fi
        done

        echo ""
        echo -e "${BLUE}To SSH into VMs, use:${NC}"
        echo -e "  $0 ssh 0    # Connect to node-0"
        echo -e "  $0 ssh 1    # Connect to node-1"
        echo -e "  etc."
        ;;

    destroy)
        echo -e "${YELLOW}Destroying all VMs...${NC}"
        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve

        # Clean up any remaining Vagrant VMs
        echo -e "${BLUE}Cleaning up remaining Vagrant VMs...${NC}"
        vagrant global-status --prune

        echo -e "${GREEN}✓ All VMs destroyed${NC}"
        ;;

    status)
        echo -e "${BLUE}VM Status:${NC}"
        cd "$TERRAFORM_DIR"
        vagrant global-status

        echo ""
        echo -e "${BLUE}Terraform State:${NC}"
        terraform show

        echo ""
        echo -e "${BLUE}VM IP Addresses:${NC}"
        VM_COUNT=$(terraform output -json 2>/dev/null | jq -r '.vm_count.value // 4')
        for i in $(seq 0 $((VM_COUNT - 1))); do
            IP="192.168.56.$((10 + i))"
            echo "  node-$i: $IP"
        done
        ;;

    ssh)
        VM_NUM="${2:-0}"
        IP="192.168.56.$((10 + VM_NUM))"
        
        echo -e "${BLUE}Connecting to node-$VM_NUM ($IP)...${NC}"
        
        # Try WSL-native location first, fall back to Vagrant default
        if [ -f "$HOME/ssh-keys/insecure_private_key" ]; then
            SSH_KEY="$HOME/ssh-keys/insecure_private_key"
        else
            SSH_KEY="$HOME/.vagrant.d/insecure_private_key"
        fi
        
        if [ ! -f "$SSH_KEY" ]; then
            echo -e "${RED}Error: Vagrant insecure private key not found${NC}"
            echo -e "${YELLOW}Trying to copy from Vagrant directory...${NC}"
            
            # Copy key to WSL filesystem to avoid permission issues
            mkdir -p "$HOME/ssh-keys"
            if [ -f "$HOME/.vagrant.d/insecure_private_key" ]; then
                cp "$HOME/.vagrant.d/insecure_private_key" "$HOME/ssh-keys/"
                chmod 600 "$HOME/ssh-keys/insecure_private_key"
                SSH_KEY="$HOME/ssh-keys/insecure_private_key"
                echo -e "${GREEN}✓ Key copied to $SSH_KEY${NC}"
            else
                echo -e "${RED}Error: Could not find Vagrant key${NC}"
                exit 1
            fi
        fi
        
        # Fix key permissions if needed
        KEY_PERMS=$(stat -c %a "$SSH_KEY" 2>/dev/null || stat -f %A "$SSH_KEY" 2>/dev/null)
        if [ "$KEY_PERMS" != "600" ]; then
            echo -e "${YELLOW}Fixing SSH key permissions...${NC}"
            chmod 600 "$SSH_KEY"
            
            # Verify it worked
            KEY_PERMS_AFTER=$(stat -c %a "$SSH_KEY" 2>/dev/null || stat -f %A "$SSH_KEY" 2>/dev/null)
            if [ "$KEY_PERMS_AFTER" != "600" ]; then
                echo -e "${RED}Warning: Could not fix permissions (WSL filesystem issue)${NC}"
                echo -e "${YELLOW}Copying key to WSL filesystem...${NC}"
                mkdir -p "$HOME/ssh-keys"
                cp "$SSH_KEY" "$HOME/ssh-keys/insecure_private_key"
                chmod 600 "$HOME/ssh-keys/insecure_private_key"
                SSH_KEY="$HOME/ssh-keys/insecure_private_key"
            fi
        fi
        
        # SSH directly to the VM
        ssh -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            vagrant@$IP
        ;;

    clean)
        echo -e "${YELLOW}Cleaning all Terraform and Vagrant files...${NC}"

        # Destroy VMs first
        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve 2>/dev/null || true

        # Clean Terraform files
        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

        # Clean Vagrant files
        rm -rf .vagrant

        # Clean Ansible inventory
        rm -f "$SCRIPT_DIR/ansible/inventory.ini"

        # Prune Vagrant global status
        vagrant global-status --prune

        echo -e "${GREEN}✓ Cleanup complete${NC}"
        ;;

    *)
        usage
        ;;
esac
