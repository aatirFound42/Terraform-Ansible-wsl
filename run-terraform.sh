#!/bin/bash
# run-terraform.sh - Run Terraform with Vagrant on WSL for Kubernetes
# Updated for 8-VM setup (2 masters + 6 workers)

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

# Function to setup SSH keys properly
setup_ssh_keys() {
    echo -e "${BLUE}Setting up SSH keys...${NC}"

    # Create ssh-keys directory
    mkdir -p "$HOME/ssh-keys"

    # Copy key to WSL filesystem with proper permissions
    if [ -f "$HOME/.vagrant.d/insecure_private_key" ]; then
        cp "$HOME/.vagrant.d/insecure_private_key" "$HOME/ssh-keys/insecure_private_key"
        chmod 600 "$HOME/ssh-keys/insecure_private_key"
        echo -e "${GREEN}✓ SSH key copied to $HOME/ssh-keys/insecure_private_key${NC}"
    else
        echo -e "${YELLOW}⚠ Vagrant key not found yet (will be available after first VM is created)${NC}"
    fi

    # Clear old SSH host keys for extended IP range
    echo -e "${BLUE}Clearing old SSH host keys...${NC}"
    for i in {10..20}; do
        ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.56.$i" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Old host keys cleared${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [init|plan|apply|destroy|status|ssh|info|clean]"
    echo ""
    echo "Commands:"
    echo "  init     - Initialize Terraform"
    echo "  plan     - Show Terraform execution plan"
    echo "  apply    - Create 8 VMs for Kubernetes cluster"
    echo "  destroy  - Destroy all VMs"
    echo "  status   - Show VM status and connectivity"
    echo "  ssh N    - SSH into VM number N (0-7)"
    echo "  info     - Show cluster information and next steps"
    echo "  clean    - Clean all Terraform and Vagrant files"
    exit 1
}

# Function to display cluster info
show_cluster_info() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}Kubernetes Cluster Information${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${BLUE}Master Nodes (Control Plane):${NC}"
    echo "  node-0 (192.168.56.10) - Primary Master"
    echo "  node-1 (192.168.56.11) - Secondary Master"
    echo ""
    echo -e "${BLUE}Worker Nodes:${NC}"
    echo "  node-2 (192.168.56.12) - Worker 1"
    echo "  node-3 (192.168.56.13) - Worker 2"
    echo "  node-4 (192.168.56.14) - Worker 3"
    echo "  node-5 (192.168.56.15) - Worker 4"
    echo "  node-6 (192.168.56.16) - Worker 5"
    echo "  node-7 (192.168.56.17) - Worker 6"
    echo ""
    echo -e "${BLUE}Resources:${NC}"
    echo "  Masters: 2 vCPU, 2GB RAM each"
    echo "  Workers: 2 vCPU, 1.5GB RAM each"
    echo "  Total: 16 vCPU, 13.5GB RAM"
    echo ""
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
        echo -e "${BLUE}Planning Terraform changes for 8-VM Kubernetes cluster...${NC}"
        cd "$TERRAFORM_DIR"
        terraform plan
        ;;

    apply)
        echo -e "${BLUE}Creating 8 VMs for Kubernetes cluster...${NC}"
        show_cluster_info
        
        cd "$TERRAFORM_DIR"

        # Check if already initialized
        if [ ! -d ".terraform" ]; then
            echo -e "${YELLOW}Terraform not initialized. Running init...${NC}"
            terraform init
        fi

        # Setup SSH keys before creating VMs
        setup_ssh_keys

        # Clean up any stale Vagrant locks
        echo -e "${BLUE}Cleaning up stale locks...${NC}"
        find .vagrant/machines -name "action_*" -type f -delete 2>/dev/null || true

        # Apply with limited parallelism to avoid Vagrant conflicts
        echo -e "${BLUE}Creating VMs sequentially to avoid conflicts...${NC}"
        echo -e "${YELLOW}This will take several minutes...${NC}"
        terraform apply -auto-approve -parallelism=1

        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}VMs Created Successfully!${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""

        # Setup SSH keys again (in case they were just created)
        setup_ssh_keys

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

        # Test connectivity with proper key
        echo ""
        echo -e "${BLUE}Testing SSH connectivity...${NC}"
        
        # Use the WSL-native key location
        SSH_KEY="$HOME/ssh-keys/insecure_private_key"

        SUCCESS_COUNT=0
        MASTER_COUNT=0
        WORKER_COUNT=0
        
        # Test masters (nodes 0-1)
        echo -e "${YELLOW}Master nodes:${NC}"
        for i in 0 1; do
            IP="192.168.56.$((10 + i))"
            echo -n "  node-$i ($IP) [Master]: "
            if timeout 5 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=5 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((SUCCESS_COUNT++))
                ((MASTER_COUNT++))
            else
                echo -e "${YELLOW}⚠ Not ready yet${NC}"
            fi
        done
        
        # Test workers (nodes 2-7)
        echo -e "${YELLOW}Worker nodes:${NC}"
        for i in 2 3 4 5 6 7; do
            IP="192.168.56.$((10 + i))"
            echo -n "  node-$i ($IP) [Worker]: "
            if timeout 5 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=5 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((SUCCESS_COUNT++))
                ((WORKER_COUNT++))
            else
                echo -e "${YELLOW}⚠ Not ready yet${NC}"
            fi
        done

        echo ""
        if [ $SUCCESS_COUNT -eq 8 ]; then
            echo -e "${GREEN}✓ All nodes accessible! ($MASTER_COUNT masters, $WORKER_COUNT workers)${NC}"
            echo ""
            show_cluster_info
            echo -e "${BLUE}Next steps:${NC}"
            echo -e "  1. Test Ansible: ${YELLOW}cd ansible && ansible all -m ping${NC}"
            echo -e "  2. Deploy K8s:   ${YELLOW}./run-ansible-k8s.sh deploy${NC}"
            echo -e "  3. Check status: ${YELLOW}./run-terraform.sh status${NC}"
        else
            echo -e "${YELLOW}⚠ $SUCCESS_COUNT/8 nodes accessible${NC}"
            echo -e "   Masters: $MASTER_COUNT/2, Workers: $WORKER_COUNT/6"
            echo -e "Wait a moment for VMs to finish booting, then test again with:"
            echo -e "  ${YELLOW}$0 status${NC}"
        fi

        echo ""
        echo -e "${BLUE}To SSH into VMs, use:${NC}"
        echo -e "  $0 ssh 0    # Connect to master-1 (node-0)"
        echo -e "  $0 ssh 1    # Connect to master-2 (node-1)"
        echo -e "  $0 ssh 2    # Connect to worker-1 (node-2)"
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
        echo -e "${BLUE}Kubernetes Cluster Status:${NC}"
        echo ""
        
        cd "$TERRAFORM_DIR"
        
        # Show Terraform outputs
        echo -e "${BLUE}Cluster Configuration:${NC}"
        terraform output -json 2>/dev/null | jq -r '
            "Masters: " + (.master_ips.value | join(", ")),
            "Workers: " + (.worker_ips.value | join(", "))
        ' 2>/dev/null || echo "Run terraform apply first"
        
        echo ""
        echo -e "${BLUE}VM Status:${NC}"
        vagrant global-status | grep "node-" || echo "No VMs running"

        echo ""
        show_cluster_info

        # Test SSH connectivity
        echo -e "${BLUE}Testing SSH connectivity...${NC}"

        # Use the WSL-native key location
        if [ -f "$HOME/ssh-keys/insecure_private_key" ]; then
            SSH_KEY="$HOME/ssh-keys/insecure_private_key"
        else
            SSH_KEY="$HOME/.vagrant.d/insecure_private_key"
        fi

        MASTER_UP=0
        WORKER_UP=0
        
        echo -e "${YELLOW}Master Nodes:${NC}"
        for i in 0 1; do
            IP="192.168.56.$((10 + i))"
            ROLE="Master-$((i + 1))"
            echo -n "  node-$i ($IP) [$ROLE]: "
            if timeout 3 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=3 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                echo -e "${GREEN}✓ Accessible${NC}"
                ((MASTER_UP++))
            else
                echo -e "${RED}✗ Not accessible${NC}"
            fi
        done
        
        echo -e "${YELLOW}Worker Nodes:${NC}"
        for i in 2 3 4 5 6 7; do
            IP="192.168.56.$((10 + i))"
            ROLE="Worker-$((i - 1))"
            echo -n "  node-$i ($IP) [$ROLE]: "
            if timeout 3 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=3 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                echo -e "${GREEN}✓ Accessible${NC}"
                ((WORKER_UP++))
            else
                echo -e "${RED}✗ Not accessible${NC}"
            fi
        done
        
        echo ""
        echo -e "${BLUE}Summary:${NC}"
        echo "  Masters: $MASTER_UP/2 accessible"
        echo "  Workers: $WORKER_UP/6 accessible"
        ;;

    ssh)
        VM_NUM="${2:-0}"
        
        if [ "$VM_NUM" -lt 0 ] || [ "$VM_NUM" -gt 7 ]; then
            echo -e "${RED}Error: VM number must be between 0 and 7${NC}"
            echo "  0-1: Master nodes"
            echo "  2-7: Worker nodes"
            exit 1
        fi
        
        IP="192.168.56.$((10 + VM_NUM))"
        
        if [ "$VM_NUM" -le 1 ]; then
            ROLE="Master-$((VM_NUM + 1))"
        else
            ROLE="Worker-$((VM_NUM - 1))"
        fi

        echo -e "${BLUE}Connecting to node-$VM_NUM ($IP) [$ROLE]...${NC}"

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

    info)
        show_cluster_info
        
        echo -e "${BLUE}Useful Commands:${NC}"
        echo "  ./run-terraform.sh status   - Check cluster status"
        echo "  ./run-terraform.sh ssh N    - SSH to node N (0-7)"
        echo "  ./run-ansible-k8s.sh deploy - Deploy Kubernetes"
        echo "  kubectl get nodes           - Check K8s nodes (after deploy)"
        echo ""
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

        # Clean SSH keys and known hosts for extended range
        echo -e "${BLUE}Cleaning SSH keys...${NC}"
        for i in {10..20}; do
            ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.56.$i" 2>/dev/null || true
        done

        echo -e "${GREEN}✓ Cleanup complete${NC}"
        ;;

    *)
        usage
        ;;
esac
