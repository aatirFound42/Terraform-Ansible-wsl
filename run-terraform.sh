#!/bin/bash
# run-terraform.sh - Run Terraform with Vagrant on WSL for Kubernetes
# Updated for 8-VM setup (2 masters + 6 workers)
# Enhanced with selective node destruction and management + VM state control

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# Function to validate node number
validate_node_number() {
    local node_num=$1
    if ! [[ "$node_num" =~ ^[0-7]$ ]]; then
        echo -e "${RED}Error: Invalid node number '$node_num'. Must be between 0-7${NC}"
        return 1
    fi
    return 0
}

# Function to get node role
get_node_role() {
    local node_num=$1
    if [ "$node_num" -le 1 ]; then
        echo "Master-$((node_num + 1))"
    else
        echo "Worker-$((node_num - 1))"
    fi
}

# Function to suspend specific node
suspend_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")
    echo -e "${YELLOW}Suspending node-$node_num [$role]...${NC}"

    cd "$TERRAFORM_DIR"
    if vagrant suspend node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num suspended${NC}"
    else
        echo -e "${RED}✗ Failed to suspend node-$node_num${NC}"
        return 1
    fi
}

# Function to resume specific node
resume_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")
    echo -e "${BLUE}Resuming node-$node_num [$role]...${NC}"

    cd "$TERRAFORM_DIR"
    if vagrant resume node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num resumed${NC}"

        # Test connectivity
        local ip="192.168.56.$((10 + node_num))"
        local ssh_key="$HOME/ssh-keys/insecure_private_key"

        echo -e "${BLUE}Waiting for VM to be ready...${NC}"
        sleep 10

        echo -n "Testing connectivity: "
        if timeout 5 ssh -i "$ssh_key" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o LogLevel=ERROR \
            vagrant@$ip "echo 'OK'" 2>/dev/null; then
            echo -e "${GREEN}✓ Accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Not ready yet (may need a moment)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to resume node-$node_num${NC}"
        return 1
    fi
}

# Function to halt specific node
halt_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")
    echo -e "${YELLOW}Halting node-$node_num [$role]...${NC}"

    cd "$TERRAFORM_DIR"
    if vagrant halt node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num halted${NC}"
    else
        echo -e "${RED}✗ Failed to halt node-$node_num${NC}"
        return 1
    fi
}

# Function to start (up) specific node
up_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")
    echo -e "${BLUE}Starting node-$node_num [$role]...${NC}"

    cd "$TERRAFORM_DIR"
    if vagrant up node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num started${NC}"

        # Test connectivity
        local ip="192.168.56.$((10 + node_num))"
        local ssh_key="$HOME/ssh-keys/insecure_private_key"

        echo -e "${BLUE}Waiting for VM to be ready...${NC}"
        sleep 15

        echo -n "Testing connectivity: "
        if timeout 5 ssh -i "$ssh_key" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o LogLevel=ERROR \
            vagrant@$ip "echo 'OK'" 2>/dev/null; then
            echo -e "${GREEN}✓ Accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Not ready yet (may need a moment)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to start node-$node_num${NC}"
        return 1
    fi
}

# Function to reload specific node
reload_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")
    echo -e "${BLUE}Reloading node-$node_num [$role]...${NC}"

    cd "$TERRAFORM_DIR"
    if vagrant reload node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num reloaded${NC}"

        # Test connectivity
        local ip="192.168.56.$((10 + node_num))"
        local ssh_key="$HOME/ssh-keys/insecure_private_key"

        echo -e "${BLUE}Waiting for VM to be ready...${NC}"
        sleep 15

        echo -n "Testing connectivity: "
        if timeout 5 ssh -i "$ssh_key" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o LogLevel=ERROR \
            vagrant@$ip "echo 'OK'" 2>/dev/null; then
            echo -e "${GREEN}✓ Accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Not ready yet (may need a moment)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to reload node-$node_num${NC}"
        return 1
    fi
}

# Function to perform bulk operations
bulk_operation() {
    local operation=$1
    shift
    local nodes=("$@")
    local success_count=0
    local fail_count=0

    echo -e "${BLUE}Performing ${operation} on ${#nodes[@]} node(s)...${NC}"
    echo ""

    for node in "${nodes[@]}"; do
        if ${operation}_node "$node"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done

    echo -e "${BLUE}Operation Summary:${NC}"
    echo -e "  ${GREEN}Success: $success_count${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "  ${RED}Failed: $fail_count${NC}"
    fi
}

# Function to suspend/resume/halt/up all nodes
bulk_state_change() {
    local action=$1
    local target=$2  # "all", "masters", "workers"
    local nodes=()

    case $target in
        all)
            nodes=(0 1 2 3 4 5 6 7)
            ;;
        masters)
            nodes=(0 1)
            ;;
        workers)
            nodes=(2 3 4 5 6 7)
            ;;
        *)
            echo -e "${RED}Error: Invalid target '$target'${NC}"
            return 1
            ;;
    esac

    case $action in
        suspend|resume|halt|up)
            bulk_operation "$action" "${nodes[@]}"
            ;;
        *)
            echo -e "${RED}Error: Invalid action '$action'${NC}"
            return 1
            ;;
    esac
}

# Function to destroy specific node
destroy_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local ip="192.168.56.$((10 + node_num))"
    local role=$(get_node_role "$node_num")

    echo -e "${YELLOW}Destroying node-$node_num ($ip) [$role]...${NC}"

    cd "$TERRAFORM_DIR"

    # Destroy using Vagrant directly
    if vagrant destroy -f node-$node_num 2>/dev/null; then
        echo -e "${GREEN}✓ node-$node_num destroyed successfully${NC}"

        # Clean SSH known host entry
        ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" 2>/dev/null || true

        # Taint the Terraform resource to force recreation on next apply
        terraform taint "null_resource.vagrant_vms[$node_num]" 2>/dev/null || \
            echo -e "${YELLOW}⚠ Note: Terraform resource tainted (normal if using destroy)${NC}"
    else
        echo -e "${RED}✗ Failed to destroy node-$node_num${NC}"
        return 1
    fi
}

# Function to destroy multiple nodes
destroy_nodes() {
    local nodes=("$@")
    local success_count=0
    local fail_count=0

    echo -e "${BLUE}Destroying ${#nodes[@]} node(s)...${NC}"
    echo ""

    for node in "${nodes[@]}"; do
        if destroy_node "$node"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done

    echo -e "${BLUE}Destruction Summary:${NC}"
    echo -e "  ${GREEN}Success: $success_count${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "  ${RED}Failed: $fail_count${NC}"
    fi
}

# Function to destroy by role (masters or workers)
destroy_by_role() {
    local role=$1
    local nodes=()

    case $role in
        masters)
            nodes=(0 1)
            echo -e "${YELLOW}Destroying all MASTER nodes (0-1)...${NC}"
            ;;
        workers)
            nodes=(2 3 4 5 6 7)
            echo -e "${YELLOW}Destroying all WORKER nodes (2-7)...${NC}"
            ;;
        *)
            echo -e "${RED}Error: Invalid role '$role'. Use 'masters' or 'workers'${NC}"
            return 1
            ;;
    esac

    echo -e "${YELLOW}This will destroy ${#nodes[@]} nodes. Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return 0
    fi

    destroy_nodes "${nodes[@]}"
}

# Function to restart a node (destroy and recreate)
restart_node() {
    local node_num=$1

    if ! validate_node_number "$node_num"; then
        return 1
    fi

    local role=$(get_node_role "$node_num")

    echo -e "${BLUE}Restarting node-$node_num [$role]...${NC}"
    echo ""

    # Destroy the node
    if destroy_node "$node_num"; then
        echo ""
        echo -e "${BLUE}Recreating node-$node_num...${NC}"

        cd "$TERRAFORM_DIR"

        # Recreate using terraform apply targeting this specific resource
        terraform apply -auto-approve -target="null_resource.vagrant_vms[$node_num]"

        echo ""
        echo -e "${GREEN}✓ node-$node_num restarted successfully${NC}"

        # Wait for VM to be ready
        echo -e "${BLUE}Waiting for VM to be ready...${NC}"
        sleep 15

        # Test connectivity
        local ip="192.168.56.$((10 + node_num))"
        local ssh_key="$HOME/ssh-keys/insecure_private_key"

        echo -n "Testing connectivity to node-$node_num ($ip): "
        if timeout 5 ssh -i "$ssh_key" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o LogLevel=ERROR \
            vagrant@$ip "echo 'OK'" 2>/dev/null; then
            echo -e "${GREEN}✓ Accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Not ready yet (may need a moment)${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to restart node-$node_num${NC}"
        return 1
    fi
}

# Function to list all nodes
list_nodes() {
    echo -e "${BLUE}Cluster Nodes:${NC}"
    echo ""

    cd "$TERRAFORM_DIR"

    # Use the WSL-native key location
    if [ -f "$HOME/ssh-keys/insecure_private_key" ]; then
        SSH_KEY="$HOME/ssh-keys/insecure_private_key"
    else
        SSH_KEY="$HOME/.vagrant.d/insecure_private_key"
    fi

    echo -e "${CYAN}Masters:${NC}"
    for i in 0 1; do
        IP="192.168.56.$((10 + i))"
        ROLE=$(get_node_role $i)

        # Get detailed status from Vagrant
        STATUS_OUTPUT=$(vagrant status node-$i 2>/dev/null | grep "node-$i")

        if echo "$STATUS_OUTPUT" | grep -q "running"; then
            STATUS="${GREEN}running${NC}"
            # Test SSH
            if timeout 3 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=3 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                SSH_STATUS="${GREEN}✓${NC}"
            else
                SSH_STATUS="${YELLOW}⚠${NC}"
            fi
        elif echo "$STATUS_OUTPUT" | grep -q "saved"; then
            STATUS="${YELLOW}suspended${NC}"
            SSH_STATUS="${YELLOW}○${NC}"
        elif echo "$STATUS_OUTPUT" | grep -q "poweroff"; then
            STATUS="${MAGENTA}halted${NC}"
            SSH_STATUS="${RED}✗${NC}"
        else
            STATUS="${RED}not created${NC}"
            SSH_STATUS="${RED}✗${NC}"
        fi

        echo -e "  [$i] node-$i ($IP) [$ROLE] - Status: $STATUS, SSH: $SSH_STATUS"
    done

    echo ""
    echo -e "${CYAN}Workers:${NC}"
    for i in 2 3 4 5 6 7; do
        IP="192.168.56.$((10 + i))"
        ROLE=$(get_node_role $i)

        # Get detailed status from Vagrant
        STATUS_OUTPUT=$(vagrant status node-$i 2>/dev/null | grep "node-$i")

        if echo "$STATUS_OUTPUT" | grep -q "running"; then
            STATUS="${GREEN}running${NC}"
            # Test SSH
            if timeout 3 ssh -i "$SSH_KEY" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=3 \
                -o LogLevel=ERROR \
                vagrant@$IP "echo 'OK'" 2>/dev/null; then
                SSH_STATUS="${GREEN}✓${NC}"
            else
                SSH_STATUS="${YELLOW}⚠${NC}"
            fi
        elif echo "$STATUS_OUTPUT" | grep -q "saved"; then
            STATUS="${YELLOW}suspended${NC}"
            SSH_STATUS="${YELLOW}○${NC}"
        elif echo "$STATUS_OUTPUT" | grep -q "poweroff"; then
            STATUS="${MAGENTA}halted${NC}"
            SSH_STATUS="${RED}✗${NC}"
        else
            STATUS="${RED}not created${NC}"
            SSH_STATUS="${RED}✗${NC}"
        fi

        echo -e "  [$i] node-$i ($IP) [$ROLE] - Status: $STATUS, SSH: $SSH_STATUS"
    done

    echo ""
    echo -e "${BLUE}Status Legend:${NC}"
    echo -e "  ${GREEN}running${NC}    - VM is powered on"
    echo -e "  ${YELLOW}suspended${NC}  - VM is saved to disk"
    echo -e "  ${MAGENTA}halted${NC}     - VM is powered off"
    echo -e "  ${RED}not created${NC} - VM doesn't exist"
}

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${BLUE}Basic Commands:${NC}"
    echo "  init                    - Initialize Terraform"
    echo "  plan                    - Show Terraform execution plan"
    echo "  apply                   - Create 8 VMs for Kubernetes cluster"
    echo "  destroy                 - Destroy all VMs"
    echo "  status                  - Show VM status and connectivity"
    echo "  info                    - Show cluster information and next steps"
    echo "  clean                   - Clean all Terraform and Vagrant files"
    echo ""
    echo -e "${BLUE}Node Management Commands:${NC}"
    echo "  list                    - List all nodes with their status"
    echo "  destroy-node N          - Destroy a specific node (0-7)"
    echo "  destroy-nodes N1 N2...  - Destroy multiple specific nodes"
    echo "  destroy-masters         - Destroy all master nodes (0-1)"
    echo "  destroy-workers         - Destroy all worker nodes (2-7)"
    echo "  restart-node N          - Restart (destroy + recreate) a specific node"
    echo ""
    echo -e "${BLUE}VM State Control:${NC}"
    echo "  suspend N               - Suspend (save) a specific node"
    echo "  suspend-all             - Suspend all nodes"
    echo "  suspend-masters         - Suspend all master nodes"
    echo "  suspend-workers         - Suspend all worker nodes"
    echo "  resume N                - Resume a suspended node"
    echo "  resume-all              - Resume all suspended nodes"
    echo "  resume-masters          - Resume all master nodes"
    echo "  resume-workers          - Resume all worker nodes"
    echo "  halt N                  - Halt (power off) a specific node"
    echo "  halt-all                - Halt all nodes"
    echo "  halt-masters            - Halt all master nodes"
    echo "  halt-workers            - Halt all worker nodes"
    echo "  up N                    - Start a halted node"
    echo "  up-all                  - Start all halted nodes"
    echo "  up-masters              - Start all master nodes"
    echo "  up-workers              - Start all worker nodes"
    echo "  reload N                - Reload (restart) a specific node"
    echo ""
    echo -e "${BLUE}SSH Commands:${NC}"
    echo "  ssh N                   - SSH into VM number N (0-7)"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 apply                      # Create all 8 VMs"
    echo "  $0 list                       # List all nodes with states"
    echo "  $0 suspend 3                  # Suspend worker-2 (save state)"
    echo "  $0 suspend-all                # Suspend all nodes"
    echo "  $0 resume 3                   # Resume worker-2"
    echo "  $0 halt-workers               # Power off all workers"
    echo "  $0 up-workers                 # Start all workers"
    echo "  $0 reload 0                   # Reload master-1"
    echo "  $0 destroy-node 3             # Destroy worker-2"
    echo "  $0 restart-node 0             # Recreate master-1"
    echo ""
    echo -e "${BLUE}Node Layout:${NC}"
    echo -e "  ${CYAN}Masters:${NC}  0-1  (192.168.56.10-11)"
    echo -e "  ${CYAN}Workers:${NC}  2-7  (192.168.56.12-17)"
    echo ""
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
    echo "  Masters: 2 vCPU, 4GB RAM each"
    echo "  Workers: 1 vCPU, 2GB RAM each"
    echo "  Total: 10 vCPU, 20GB RAM"
    echo ""
}

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

# Parse command
COMMAND="${1:-}"

if [ -z "$COMMAND" ]; then
    usage
fi

case $COMMAND in

    help|-h|--help)
        usage
        ;;

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
        echo -e "${YELLOW}This will destroy all 8 nodes. Continue? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi

        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve

        # Clean up any remaining Vagrant VMs
        echo -e "${BLUE}Cleaning up remaining Vagrant VMs...${NC}"
        vagrant global-status --prune

        echo -e "${GREEN}✓ All VMs destroyed${NC}"
        ;;

    list)
        list_nodes
        ;;

    destroy-node)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 destroy-node N"
            echo "Example: $0 destroy-node 3"
            exit 1
        fi
        destroy_node "$2"
        ;;

    destroy-nodes)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: At least one node number required${NC}"
            echo "Usage: $0 destroy-nodes N1 N2 N3..."
            echo "Example: $0 destroy-nodes 2 3 4"
            exit 1
        fi
        shift  # Remove 'destroy-nodes' from arguments

        # Validate all nodes first
        for node in "$@"; do
            if ! validate_node_number "$node"; then
                exit 1
            fi
        done

        destroy_nodes "$@"
        ;;

    destroy-masters)
        destroy_by_role "masters"
        ;;

    destroy-workers)
        destroy_by_role "workers"
        ;;

    restart-node)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 restart-node N"
            echo "Example: $0 restart-node 0"
            exit 1
        fi
        restart_node "$2"
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
        echo "  ./run-terraform.sh status          - Check cluster status"
        echo "  ./run-terraform.sh list            - List all nodes"
        echo "  ./run-terraform.sh ssh N           - SSH to node N (0-7)"
        echo "  ./run-terraform.sh destroy-node N  - Destroy specific node"
        echo "  ./run-terraform.sh restart-node N  - Restart specific node"
        echo "  ./run-ansible-k8s.sh deploy        - Deploy Kubernetes"
        echo "  kubectl get nodes                  - Check K8s nodes (after deploy)"
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

    # VM State Control Commands
    suspend)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 suspend N"
            exit 1
        fi
        suspend_node "$2"
        ;;

    suspend-all)
        bulk_state_change "suspend" "all"
        ;;

    suspend-masters)
        bulk_state_change "suspend" "masters"
        ;;

    suspend-workers)
        bulk_state_change "suspend" "workers"
        ;;

    resume)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 resume N"
            exit 1
        fi
        resume_node "$2"
        ;;

    resume-all)
        bulk_state_change "resume" "all"
        ;;

    resume-masters)
        bulk_state_change "resume" "masters"
        ;;

    resume-workers)
        bulk_state_change "resume" "workers"
        ;;

    halt)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 halt N"
            exit 1
        fi
        halt_node "$2"
        ;;

    halt-all)
        bulk_state_change "halt" "all"
        ;;

    halt-masters)
        bulk_state_change "halt" "masters"
        ;;

    halt-workers)
        bulk_state_change "halt" "workers"
        ;;

    up)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 up N"
            exit 1
        fi
        up_node "$2"
        ;;

    up-all)
        bulk_state_change "up" "all"
        ;;

    up-masters)
        bulk_state_change "up" "masters"
        ;;

    up-workers)
        bulk_state_change "up" "workers"
        ;;

    reload)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Node number required${NC}"
            echo "Usage: $0 reload N"
            exit 1
        fi
        reload_node "$2"
        ;;

    *)
        if [ -n "$COMMAND" ]; then
            echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
            echo ""
        fi
        usage
        ;;

esac
