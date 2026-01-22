#!/bin/bash
# shutdown-all.sh - Gracefully shutdown all services and VMs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_SCRIPT="$SCRIPT_DIR/run-ansible.sh"

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Shutdown Sequence${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Function to stop Docker containers
stop_containers() {
    echo -e "\n${YELLOW}Step 1: Stopping all Docker containers...${NC}"
    if [ -f "$ANSIBLE_SCRIPT" ]; then
        "$ANSIBLE_SCRIPT" command 'docker stop $(docker ps -aq) 2>/dev/null || true' || true
        echo -e "${GREEN}✓ Docker containers stopped${NC}"
        
        echo -e "\n${BLUE}Verifying containers are stopped...${NC}"
        "$ANSIBLE_SCRIPT" command 'docker ps'
    else
        echo -e "${RED}✗ Ansible script not found, skipping container shutdown${NC}"
    fi
}

# Function to shutdown VMs
shutdown_vms() {
    echo -e "\n${YELLOW}Step 2: Shutting down VMs...${NC}"
    
    # Check if Vagrant is available
    if command -v vagrant &> /dev/null && [ -f "Vagrantfile" ]; then
        echo -e "${BLUE}Detected Vagrant setup${NC}"
        echo -e "${YELLOW}Choose shutdown method:${NC}"
        echo "  1) Suspend (fast restart, saves state)"
        echo "  2) Halt (clean shutdown)"
        echo "  3) Destroy (remove VMs completely)"
        echo "  4) Skip VM shutdown"
        read -p "Enter choice [1-4]: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}Suspending VMs...${NC}"
                vagrant suspend
                echo -e "${GREEN}✓ VMs suspended${NC}"
                echo -e "${CYAN}Tomorrow: Run 'vagrant resume' to continue${NC}"
                ;;
            2)
                echo -e "${BLUE}Halting VMs...${NC}"
                vagrant halt
                echo -e "${GREEN}✓ VMs halted${NC}"
                echo -e "${CYAN}Tomorrow: Run 'vagrant up' to start${NC}"
                ;;
            3)
                echo -e "${RED}⚠️  This will destroy all VMs!${NC}"
                read -p "Are you sure? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                    vagrant destroy -f
                    echo -e "${GREEN}✓ VMs destroyed${NC}"
                    echo -e "${CYAN}Tomorrow: Run 'vagrant up' then './run-ansible.sh deploy'${NC}"
                else
                    echo -e "${YELLOW}Destroy cancelled${NC}"
                fi
                ;;
            4)
                echo -e "${YELLOW}Skipping VM shutdown${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice, skipping VM shutdown${NC}"
                ;;
        esac
    
    # Check if virsh is available
    elif command -v virsh &> /dev/null; then
        echo -e "${BLUE}Detected libvirt/virsh setup${NC}"
        echo -e "${YELLOW}Listing running VMs:${NC}"
        virsh list
        
        echo -e "\n${YELLOW}Choose shutdown method:${NC}"
        echo "  1) Shutdown all (graceful)"
        echo "  2) Force destroy all"
        echo "  3) Skip"
        read -p "Enter choice [1-3]: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}Shutting down VMs gracefully...${NC}"
                for vm in $(virsh list --name); do
                    if [ -n "$vm" ]; then
                        echo -e "  Shutting down: $vm"
                        virsh shutdown "$vm"
                    fi
                done
                echo -e "${GREEN}✓ Shutdown signal sent to all VMs${NC}"
                ;;
            2)
                echo -e "${BLUE}Force destroying VMs...${NC}"
                for vm in $(virsh list --name); do
                    if [ -n "$vm" ]; then
                        echo -e "  Destroying: $vm"
                        virsh destroy "$vm"
                    fi
                done
                echo -e "${GREEN}✓ All VMs destroyed${NC}"
                ;;
            3)
                echo -e "${YELLOW}Skipping VM shutdown${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice, skipping VM shutdown${NC}"
                ;;
        esac
    
    # Check if Terraform is available
    elif command -v terraform &> /dev/null && [ -f "main.tf" -o -f "terraform/main.tf" ]; then
        echo -e "${BLUE}Detected Terraform setup${NC}"
        echo -e "${YELLOW}Choose shutdown method:${NC}"
        echo "  1) Stop VMs (terraform apply with vm_count=0)"
        echo "  2) Destroy all (terraform destroy)"
        echo "  3) Skip"
        read -p "Enter choice [1-3]: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}Stopping VMs via Terraform...${NC}"
                if [ -d "terraform" ]; then
                    cd terraform
                fi
                terraform apply -auto-approve -var="vm_count=0" 2>/dev/null || \
                    echo -e "${RED}Note: If this fails, you may need to run 'terraform destroy' instead${NC}"
                echo -e "${GREEN}✓ VMs stopped${NC}"
                ;;
            2)
                echo -e "${BLUE}Destroying all resources via Terraform...${NC}"
                if [ -d "terraform" ]; then
                    cd terraform
                fi
                terraform destroy -auto-approve
                echo -e "${GREEN}✓ All resources destroyed${NC}"
                ;;
            3)
                echo -e "${YELLOW}Skipping VM shutdown${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice, skipping VM shutdown${NC}"
                ;;
        esac
    else
        echo -e "${YELLOW}No VM management tool detected (vagrant/virsh/terraform)${NC}"
        echo -e "${YELLOW}Please shut down VMs manually${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "\n${YELLOW}Step 3: Final Status Check${NC}"
    
    if command -v vagrant &> /dev/null && [ -f "Vagrantfile" ]; then
        echo -e "${BLUE}Vagrant Status:${NC}"
        vagrant status
    elif command -v virsh &> /dev/null; then
        echo -e "${BLUE}VM Status:${NC}"
        virsh list --all
    fi
}

# Main execution
main() {
    echo -e "\n${BLUE}This will:${NC}"
    echo "  1. Stop all Docker containers on all VMs"
    echo "  2. Shutdown VMs"
    echo ""
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Shutdown cancelled${NC}"
        exit 0
    fi

    stop_containers
    shutdown_vms
    show_status

    echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Shutdown Complete${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "\n${BLUE}To restart tomorrow:${NC}"
    echo -e "  ${GREEN}vagrant resume${NC}  (if suspended)"
    echo -e "  ${GREEN}vagrant up${NC}      (if halted)"
    echo -e "  ${GREEN}./run-ansible.sh health${NC}  (to verify services)"
    echo ""
}

# Run main function
main
