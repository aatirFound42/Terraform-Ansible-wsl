#!/bin/bash
# run-ansible.sh - Run Ansible playbooks against VMs (Enhanced Multi-VM Support)
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
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.ini"
PLAYBOOK="$ANSIBLE_DIR/playbook.yml"

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
    cat << EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
${BLUE}Ansible Multi-VM Deployment Tool${NC}
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]

${YELLOW}Basic Commands:${NC}
  ${GREEN}ping${NC}              - Test connectivity to all nodes
  ${GREEN}facts${NC}             - Gather facts from all nodes
  ${GREEN}command${NC} 'CMD'     - Run command on all nodes
  ${GREEN}playbook${NC} FILE.yml - Run a playbook
  ${GREEN}shell${NC}             - Interactive shell on all nodes

${YELLOW}Deployment Commands:${NC}
  ${GREEN}deploy${NC}            - Full deployment (all VMs)
  ${GREEN}deploy-app${NC}        - Deploy application only (3 VMs)
  ${GREEN}deploy-prometheus${NC} - Deploy Prometheus only
  ${GREEN}deploy-grafana${NC}    - Deploy Grafana only
  ${GREEN}deploy-observability${NC} - Deploy Prometheus + Grafana

${YELLOW}Targeted Commands:${NC}
  ${GREEN}ping-app${NC}          - Ping application VMs only
  ${GREEN}ping-monitoring${NC}   - Ping monitoring VMs only
  ${GREEN}logs-app${NC} [VM]     - View application logs (optionally specify VM: 1, 2, or 3)
  ${GREEN}logs-prometheus${NC}   - View Prometheus logs
  ${GREEN}logs-grafana${NC}      - View Grafana logs
  ${GREEN}restart-app${NC} [VM]  - Restart application (optionally specify VM: 1, 2, or 3)
  ${GREEN}restart-prometheus${NC} - Restart Prometheus
  ${GREEN}restart-grafana${NC}   - Restart Grafana

${YELLOW}Health Check Commands:${NC}
  ${GREEN}health${NC}            - Check health of all services
  ${GREEN}health-app${NC}        - Check application health on all app VMs
  ${GREEN}health-monitoring${NC} - Check Prometheus and Grafana health

${YELLOW}Status Commands:${NC}
  ${GREEN}status${NC}            - Show status of all services
  ${GREEN}ps${NC}                - Show running Docker containers on all VMs
  ${GREEN}urls${NC}              - Display all service URLs

${YELLOW}Examples:${NC}
  $0 deploy                    # Full deployment
  $0 deploy-app                # Deploy apps only
  $0 logs-app 1                # View logs from app-vm-1
  $0 restart-app 2             # Restart app on app-vm-2
  $0 command 'docker ps'       # Run command on all VMs
  $0 health                    # Check all services

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
    exit 1
}

# Function to run playbook
run_playbook() {
    local limit="$1"
    local extra_args="${2:-}"
    
    echo -e "${BLUE}Running playbook...${NC}"
    if [ -n "$limit" ]; then
        echo -e "${YELLOW}Limited to: $limit${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --limit "$limit" $extra_args
    else
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" $extra_args
    fi
}

# Function to check service health
check_health() {
    local host="$1"
    local url="$2"
    local name="$3"
    
    echo -e "${BLUE}Checking $name health on $host...${NC}"
    if ansible "$host" -i "$INVENTORY" -m uri -a "url=$url method=GET status_code=200" &> /dev/null; then
        echo -e "${GREEN}✓ $name is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ $name is unhealthy${NC}"
        return 1
    fi
}

COMMAND="${1:-help}"

case $COMMAND in
    # ========================================================================
    # Basic Commands
    # ========================================================================
    ping)
        echo -e "${BLUE}Testing Ansible connectivity to all nodes...${NC}"
        ansible all -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ All nodes responding${NC}"
        ;;
    
    ping-app)
        echo -e "${BLUE}Testing connectivity to application VMs...${NC}"
        ansible app_nodes -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ Application VMs responding${NC}"
        ;;
    
    ping-monitoring)
        echo -e "${BLUE}Testing connectivity to monitoring VMs...${NC}"
        ansible 'prometheus_node:grafana_node' -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ Monitoring VMs responding${NC}"
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
    
    shell)
        echo -e "${BLUE}Starting interactive shell on all nodes...${NC}"
        echo -e "${YELLOW}Type your commands (Ctrl+D to exit):${NC}"
        ansible all -i "$INVENTORY" -m shell -a 'bash'
        ;;
    
    playbook)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No playbook specified${NC}"
            usage
        fi
        CUSTOM_PLAYBOOK="$2"
        if [ ! -f "$CUSTOM_PLAYBOOK" ]; then
            CUSTOM_PLAYBOOK="$ANSIBLE_DIR/$2"
            if [ ! -f "$CUSTOM_PLAYBOOK" ]; then
                echo -e "${RED}Error: Playbook not found: $2${NC}"
                exit 1
            fi
        fi
        echo -e "${BLUE}Running playbook: ${YELLOW}$CUSTOM_PLAYBOOK${NC}"
        ansible-playbook -i "$INVENTORY" "$CUSTOM_PLAYBOOK"
        ;;

    # ========================================================================
    # Deployment Commands
    # ========================================================================
    deploy)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Starting Full Multi-VM Deployment${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        run_playbook ""
        ;;
    
    deploy-app)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Application to App VMs${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        run_playbook "app_nodes"
        ;;
    
    deploy-prometheus)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Prometheus${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        run_playbook "prometheus_node"
        ;;
    
    deploy-grafana)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Grafana${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        run_playbook "grafana_node"
        ;;
    
    deploy-observability)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Observability Stack${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        run_playbook "prometheus_node:grafana_node"
        ;;

    # ========================================================================
    # Log Commands
    # ========================================================================
    logs-app)
        VM_NUM="${2:-all}"
        if [ "$VM_NUM" = "all" ]; then
            echo -e "${BLUE}Fetching application logs from all app VMs...${NC}"
            ansible app_nodes -i "$INVENTORY" -m shell -a "docker logs python-app-instance --tail 50"
        elif [[ "$VM_NUM" =~ ^[1-3]$ ]]; then
            echo -e "${BLUE}Fetching application logs from app-vm-$VM_NUM...${NC}"
            ansible "app-vm-$VM_NUM" -i "$INVENTORY" -m shell -a "docker logs python-app-instance --tail 50"
        else
            echo -e "${RED}Error: Invalid VM number. Use 1, 2, or 3${NC}"
            exit 1
        fi
        ;;
    
    logs-prometheus)
        echo -e "${BLUE}Fetching Prometheus logs...${NC}"
        ansible prometheus_node -i "$INVENTORY" -m shell -a "docker logs prometheus --tail 50"
        ;;
    
    logs-grafana)
        echo -e "${BLUE}Fetching Grafana logs...${NC}"
        ansible grafana_node -i "$INVENTORY" -m shell -a "docker logs grafana --tail 50"
        ;;

    # ========================================================================
    # Restart Commands
    # ========================================================================
    restart-app)
        VM_NUM="${2:-all}"
        if [ "$VM_NUM" = "all" ]; then
            echo -e "${BLUE}Restarting application on all app VMs...${NC}"
            ansible app_nodes -i "$INVENTORY" -m shell -a "docker restart python-app-instance"
            echo -e "${GREEN}✓ Application restarted on all VMs${NC}"
        elif [[ "$VM_NUM" =~ ^[1-3]$ ]]; then
            echo -e "${BLUE}Restarting application on app-vm-$VM_NUM...${NC}"
            ansible "app-vm-$VM_NUM" -i "$INVENTORY" -m shell -a "docker restart python-app-instance"
            echo -e "${GREEN}✓ Application restarted on app-vm-$VM_NUM${NC}"
        else
            echo -e "${RED}Error: Invalid VM number. Use 1, 2, or 3${NC}"
            exit 1
        fi
        ;;
    
    restart-prometheus)
        echo -e "${BLUE}Restarting Prometheus...${NC}"
        ansible prometheus_node -i "$INVENTORY" -m shell -a "docker restart prometheus"
        echo -e "${GREEN}✓ Prometheus restarted${NC}"
        ;;
    
    restart-grafana)
        echo -e "${BLUE}Restarting Grafana...${NC}"
        ansible grafana_node -i "$INVENTORY" -m shell -a "docker restart grafana"
        echo -e "${GREEN}✓ Grafana restarted${NC}"
        ;;

    # ========================================================================
    # Health Check Commands
    # ========================================================================
    health)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Checking Health of All Services${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        # Check app VMs
        echo -e "\n${YELLOW}Application VMs:${NC}"
        for i in 1 2 3; do
            ansible "app-vm-$i" -i "$INVENTORY" -m uri -a "url=http://localhost:5000/api/health method=GET status_code=200" 2>/dev/null && \
                echo -e "${GREEN}✓ app-vm-$i is healthy${NC}" || \
                echo -e "${RED}✗ app-vm-$i is unhealthy${NC}"
        done
        
        # Check Prometheus
        echo -e "\n${YELLOW}Monitoring Stack:${NC}"
        ansible prometheus_node -i "$INVENTORY" -m uri -a "url=http://localhost:9090/-/healthy method=GET status_code=200" 2>/dev/null && \
            echo -e "${GREEN}✓ Prometheus is healthy${NC}" || \
            echo -e "${RED}✗ Prometheus is unhealthy${NC}"
        
        # Check Grafana
        ansible grafana_node -i "$INVENTORY" -m uri -a "url=http://localhost:3000/api/health method=GET status_code=200" 2>/dev/null && \
            echo -e "${GREEN}✓ Grafana is healthy${NC}" || \
            echo -e "${RED}✗ Grafana is unhealthy${NC}"
        
        echo ""
        ;;
    
    health-app)
        echo -e "${BLUE}Checking application health on all app VMs...${NC}"
        for i in 1 2 3; do
            ansible "app-vm-$i" -i "$INVENTORY" -m uri -a "url=http://localhost:5000/api/health method=GET status_code=200" 2>/dev/null && \
                echo -e "${GREEN}✓ app-vm-$i is healthy${NC}" || \
                echo -e "${RED}✗ app-vm-$i is unhealthy${NC}"
        done
        ;;
    
    health-monitoring)
        echo -e "${BLUE}Checking monitoring stack health...${NC}"
        ansible prometheus_node -i "$INVENTORY" -m uri -a "url=http://localhost:9090/-/healthy method=GET status_code=200" 2>/dev/null && \
            echo -e "${GREEN}✓ Prometheus is healthy${NC}" || \
            echo -e "${RED}✗ Prometheus is unhealthy${NC}"
        
        ansible grafana_node -i "$INVENTORY" -m uri -a "url=http://localhost:3000/api/health method=GET status_code=200" 2>/dev/null && \
            echo -e "${GREEN}✓ Grafana is healthy${NC}" || \
            echo -e "${RED}✗ Grafana is unhealthy${NC}"
        ;;

    # ========================================================================
    # Status Commands
    # ========================================================================
    status)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Service Status Overview${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        echo -e "\n${YELLOW}Application VMs:${NC}"
        ansible app_nodes -i "$INVENTORY" -m shell -a "docker ps --filter 'name=python-app-instance' --format 'table {{.Names}}\t{{.Status}}'"
        
        echo -e "\n${YELLOW}Prometheus:${NC}"
        ansible prometheus_node -i "$INVENTORY" -m shell -a "docker ps --filter 'name=prometheus' --format 'table {{.Names}}\t{{.Status}}'"
        
        echo -e "\n${YELLOW}Grafana:${NC}"
        ansible grafana_node -i "$INVENTORY" -m shell -a "docker ps --filter 'name=grafana' --format 'table {{.Names}}\t{{.Status}}'"
        
        echo -e "\n${YELLOW}Node Exporters (All VMs):${NC}"
        ansible all_vms -i "$INVENTORY" -m shell -a "docker ps --filter 'name=node-exporter' --format 'table {{.Names}}\t{{.Status}}'"
        ;;
    
    ps)
        echo -e "${BLUE}Showing Docker containers on all VMs...${NC}"
        ansible all -i "$INVENTORY" -m shell -a "echo '=== \$(hostname) ===' && docker ps"
        ;;
    
    urls)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Service URLs${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        echo -e "\n${YELLOW}📦 Application VMs:${NC}"
        for i in 1 2 3; do
            IP=$(ansible "app-vm-$i" -i "$INVENTORY" -m shell -a "hostname -I | awk '{print \$1}'" 2>/dev/null | grep -v "CHANGED" | tail -1 | xargs)
            echo -e "   App VM $i: ${GREEN}http://$IP:5000${NC}"
            echo -e "   Health:    ${GREEN}http://$IP:5000/api/health${NC}"
        done
        
        echo -e "\n${YELLOW}📊 Monitoring Stack:${NC}"
        PROM_IP=$(ansible prometheus_node -i "$INVENTORY" -m shell -a "hostname -I | awk '{print \$1}'" 2>/dev/null | grep -v "CHANGED" | tail -1 | xargs)
        GRAF_IP=$(ansible grafana_node -i "$INVENTORY" -m shell -a "hostname -I | awk '{print \$1}'" 2>/dev/null | grep -v "CHANGED" | tail -1 | xargs)
        
        echo -e "   Prometheus: ${GREEN}http://$PROM_IP:9090${NC}"
        echo -e "   Grafana:    ${GREEN}http://$GRAF_IP:3000${NC} (admin/admin)"
        
        echo -e "\n${YELLOW}🔍 Node Exporters (Port 9100):${NC}"
        ansible all_vms -i "$INVENTORY" -m shell -a "echo \"   \$(hostname): http://\$(hostname -I | awk '{print \$1}'):9100\"" 2>/dev/null | grep -v "CHANGED" | grep "http"
        
        echo ""
        ;;

    # ========================================================================
    # Help
    # ========================================================================
    help|--help|-h|"")
        usage
        ;;
    
    *)
        echo -e "${RED}Error: Unknown command: $COMMAND${NC}"
        echo ""
        usage
        ;;
esac
