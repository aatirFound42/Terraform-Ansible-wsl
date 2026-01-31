#!/bin/bash
# run-ansible-k8s.sh - Kubernetes HA Multi-Master Deployment Tool (ENHANCED)
#
# NEW FEATURES:
# - Deploy frontend/backend independently
# - Scale frontend/backend
# - View frontend/backend logs
# - Restart frontend/backend
#
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
PLAYBOOK="$ANSIBLE_DIR/playbook-k8s.yml"

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

usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Kubernetes HA Multi-Master Deployment Tool (9 VMs)${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Cluster Management:${NC}"
    echo -e "  ${GREEN}ping${NC}              - Test connectivity to all nodes"
    echo -e "  ${GREEN}ping-lb${NC}           - Test connectivity to load balancer"
    echo -e "  ${GREEN}ping-masters${NC}      - Test connectivity to master nodes"
    echo -e "  ${GREEN}ping-workers${NC}      - Test connectivity to worker nodes"
    echo ""
    echo -e "${YELLOW}Deployment (Full):${NC}"
    echo -e "  ${GREEN}deploy${NC}            - Full HA Kubernetes cluster deployment"
    echo ""
    echo -e "${YELLOW}Deployment (Phased):${NC}"
    echo -e "  ${GREEN}phase1${NC}            - Deploy LB + Primary Master + CNI"
    echo -e "  ${GREEN}phase2${NC}            - Join Secondary Masters"
    echo -e "  ${GREEN}phase3${NC}            - Join Worker Nodes"
    echo -e "  ${GREEN}phase4${NC}            - Deploy Applications"
    echo ""
    echo -e "${YELLOW}Deployment (Granular):${NC}"
    echo -e "  ${GREEN}deploy-lb${NC}         - Deploy load balancer only"
    echo -e "  ${GREEN}deploy-primary${NC}    - Deploy primary master only"
    echo -e "  ${GREEN}deploy-secondary${NC}  - Join secondary masters"
    echo -e "  ${GREEN}deploy-workers${NC}    - Join worker nodes"
    echo -e "  ${GREEN}deploy-apps${NC}       - Deploy applications only"
    echo ""
    echo -e "${YELLOW}🆕 Frontend/Backend Management:${NC}"
    echo -e "  ${GREEN}deploy-frontend${NC}   - Deploy/update frontend only"
    echo -e "  ${GREEN}deploy-backend${NC}    - Deploy/update backend only"
    echo -e "  ${GREEN}deploy-fullstack${NC}  - Deploy/update both frontend & backend"
    echo -e "  ${GREEN}scale-frontend${NC} N  - Scale frontend to N replicas"
    echo -e "  ${GREEN}scale-backend${NC} N   - Scale backend to N replicas"
    echo -e "  ${GREEN}restart-frontend${NC}  - Restart frontend deployment"
    echo -e "  ${GREEN}restart-backend${NC}   - Restart backend deployment"
    echo -e "  ${GREEN}logs-frontend${NC}     - View frontend logs"
    echo -e "  ${GREEN}logs-backend${NC}      - View backend logs"
    echo -e "  ${GREEN}status-fullstack${NC}  - Show frontend & backend status"
    echo -e "  ${GREEN}delete-frontend${NC}   - Delete frontend deployment"
    echo -e "  ${GREEN}delete-backend${NC}    - Delete backend deployment"
    echo ""
    echo -e "${YELLOW}Load Balancer:${NC}"
    echo -e "  ${GREEN}lb-status${NC}         - Check HAProxy status"
    echo -e "  ${GREEN}lb-stats${NC}          - Show HAProxy statistics URL"
    echo -e "  ${GREEN}lb-config${NC}         - View HAProxy configuration"
    echo -e "  ${GREEN}lb-restart${NC}        - Restart HAProxy service"
    echo ""
    echo -e "${YELLOW}Kubectl Commands (run on masters):${NC}"
    echo -e "  ${GREEN}kubectl${NC} [ARGS]    - Run kubectl command on primary master"
    echo -e "  ${GREEN}nodes${NC}             - Show cluster nodes status"
    echo -e "  ${GREEN}pods${NC}              - Show all pods in monitoring namespace"
    echo -e "  ${GREEN}services${NC}          - Show all services"
    echo -e "  ${GREEN}deployments${NC}       - Show all deployments"
    echo -e "  ${GREEN}describe-pod${NC} NAME - Describe specific pod"
    echo -e "  ${GREEN}logs-pod${NC} NAME     - View pod logs"
    echo ""
    echo -e "${YELLOW}Application Management:${NC}"
    echo -e "  ${GREEN}scale-app${NC} N       - Scale python-app to N replicas"
    echo -e "  ${GREEN}scale-selenium${NC} N  - Scale selenium-chrome to N replicas"
    echo -e "  ${GREEN}restart-app${NC}       - Restart python-app deployment"
    echo -e "  ${GREEN}restart-prometheus${NC} - Restart Prometheus deployment"
    echo -e "  ${GREEN}restart-grafana${NC}   - Restart Grafana deployment"
    echo -e "  ${GREEN}restart-selenium${NC}  - Restart Selenium hub and nodes"
    echo ""
    echo -e "${YELLOW}Health & Status:${NC}"
    echo -e "  ${GREEN}health${NC}            - Check health of all services"
    echo -e "  ${GREEN}status${NC}            - Show cluster and pod status"
    echo -e "  ${GREEN}urls${NC}              - Display all service URLs"
    echo -e "  ${GREEN}metrics${NC}           - Show resource usage"
    echo -e "  ${GREEN}ha-test${NC}           - Test HA failover capability"
    echo ""
    echo -e "${YELLOW}Testing:${NC}"
    echo -e "  ${GREEN}selenium-test${NC}     - Run Selenium test manually"
    echo -e "  ${GREEN}selenium-metrics${NC}  - View Selenium metrics from Pushgateway"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  ${GREEN}logs-node${NC} NODE    - View kubelet logs on a node"
    echo -e "  ${GREEN}logs-lb${NC}           - View HAProxy logs"
    echo -e "  ${GREEN}debug-apiserver${NC}   - Debug API server issues"
    echo -e "  ${GREEN}debug-cluster${NC}     - Full cluster diagnostic"
    echo -e "  ${GREEN}drain${NC} NODE        - Drain a node for maintenance"
    echo -e "  ${GREEN}uncordon${NC} NODE     - Mark node as schedulable"
    echo -e "  ${GREEN}top-nodes${NC}         - Show node resource usage"
    echo -e "  ${GREEN}top-pods${NC}          - Show pod resource usage"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 deploy                    # Full deployment (all phases)"
    echo "  $0 deploy-fullstack          # Deploy only frontend & backend"
    echo "  $0 scale-frontend 3          # Scale frontend to 3 replicas"
    echo "  $0 logs-backend              # View backend logs"
    echo "  $0 status-fullstack          # Check frontend & backend status"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    exit 1
}

# Run kubectl on primary master (IMPROVED ERROR HANDLING)
run_kubectl() {
    local output
    local exit_code

    # Capture output and exit code
    output=$(ansible k8s_primary_master -i "$INVENTORY" -m shell \
        -a "kubectl $*" \
        -e "ansible_become=yes" 2>&1)
    exit_code=$?

    # Check for errors
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error executing kubectl command${NC}" >&2
        echo "$output" | grep -v "CHANGED" | grep -v "rc=0" >&2
        return 1
    fi

    # Filter and display output
    echo "$output" | grep -v "CHANGED" | grep -v "rc=0" | grep -v "^$" || true
    return 0
}

# Get private IP (more robust - searches all interfaces)
get_private_ip() {
    local host="$1"
    ansible "$host" -i "$INVENTORY" -m shell \
        -a "hostname -I | tr ' ' '\n' | grep -E '^192\.168\.56\.' | head -1" 2>/dev/null \
        | grep -v "CHANGED" | grep -E "192\.168\.56\." | tail -1 | xargs
}

# Get load balancer IP (IMPROVED WITH MULTIPLE FALLBACKS)
get_lb_ip() {
    local ip=""

    # Method 1: Try to get from running node first
    ip=$(ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
        -a "hostname -I | tr ' ' '\n' | grep -E '^192\.168\.56\.' | head -1" 2>/dev/null \
        | grep -v "CHANGED" | grep -E "192\.168\.56\." | tail -1 | xargs)

    # Method 2: Use ansible-inventory if available
    if [ -z "$ip" ] && command -v ansible-inventory &> /dev/null; then
        ip=$(ansible-inventory -i "$INVENTORY" --host lb-0 2>/dev/null | \
             grep -oP '"ansible_host":\s*"\K[^"]+' || true)
    fi

    # Method 3: Parse inventory file directly (more robust)
    if [ -z "$ip" ]; then
        ip=$(awk '
            /^\[k8s_loadbalancer\]/ { in_section=1; next }
            /^\[/ { in_section=0 }
            in_section && /ansible_host=/ {
                match($0, /ansible_host=([0-9.]+)/, arr)
                print arr[1]
                exit
            }
        ' "$INVENTORY")
    fi

    # Method 4: Last resort - grep with robust pattern
    if [ -z "$ip" ]; then
        ip=$(grep -A2 "^\[k8s_loadbalancer\]" "$INVENTORY" | \
             grep "ansible_host" | \
             sed -n 's/.*ansible_host=\([0-9.]*\).*/\1/p' | \
             head -1)
    fi

    echo "$ip"
}

COMMAND="${1:-help}"

case $COMMAND in
    # ========================================================================
    # Basic Connectivity
    # ========================================================================
    ping)
        echo -e "${BLUE}Testing connectivity to all nodes...${NC}"
        ansible all_vms -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ All nodes responding${NC}"
        ;;

    ping-lb)
        echo -e "${BLUE}Testing connectivity to load balancer...${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ Load balancer responding${NC}"
        ;;

    ping-masters)
        echo -e "${BLUE}Testing connectivity to master nodes...${NC}"
        ansible k8s_masters -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ Master nodes responding${NC}"
        ;;

    ping-workers)
        echo -e "${BLUE}Testing connectivity to worker nodes...${NC}"
        ansible k8s_workers -i "$INVENTORY" -m ping
        echo -e "${GREEN}✓ Worker nodes responding${NC}"
        ;;

    # ========================================================================
    # Frontend/Backend Management (NEW)
    # ========================================================================
    deploy-frontend)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Frontend${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        # Copy manifest to primary master
        ansible k8s_primary_master -i "$INVENTORY" -m copy \
            -a "src=$ANSIBLE_DIR/files/k8s/frontend-deployment.yml dest=/tmp/frontend-deployment.yml" -b
        
        # Apply manifest
        run_kubectl "apply -f /tmp/frontend-deployment.yml"
        
        echo -e "${GREEN}✓ Frontend deployment updated${NC}"
        echo -e "${YELLOW}Waiting for rollout...${NC}"
        run_kubectl "rollout status deployment/cicd-frontend -n monitoring --timeout=120s" || true
        
        echo ""
        echo -e "${GREEN}✓ Frontend deployed successfully${NC}"
        echo -e "${YELLOW}Access at:${NC} http://$(get_private_ip 'node-0'):30300"
        ;;

    deploy-backend)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Backend${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        # Copy manifest to primary master
        ansible k8s_primary_master -i "$INVENTORY" -m copy \
            -a "src=$ANSIBLE_DIR/files/k8s/backend-deployment.yml dest=/tmp/backend-deployment.yml" -b
        
        # Apply manifest
        run_kubectl "apply -f /tmp/backend-deployment.yml"
        
        echo -e "${GREEN}✓ Backend deployment updated${NC}"
        echo -e "${YELLOW}Waiting for rollout...${NC}"
        run_kubectl "rollout status deployment/cicd-backend -n monitoring --timeout=120s" || true
        
        echo ""
        echo -e "${GREEN}✓ Backend deployed successfully${NC}"
        echo -e "${YELLOW}Access at:${NC} http://$(get_private_ip 'node-0'):30500"
        ;;

    deploy-fullstack)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Full Stack (Frontend + Backend)${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        echo -e "${YELLOW}Deploying Backend...${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m copy \
            -a "src=$ANSIBLE_DIR/files/k8s/backend-deployment.yml dest=/tmp/backend-deployment.yml" -b
        run_kubectl "apply -f /tmp/backend-deployment.yml"
        
        echo -e "${YELLOW}Deploying Frontend...${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m copy \
            -a "src=$ANSIBLE_DIR/files/k8s/frontend-deployment.yml dest=/tmp/frontend-deployment.yml" -b
        run_kubectl "apply -f /tmp/frontend-deployment.yml"
        
        echo -e "${YELLOW}Waiting for rollouts...${NC}"
        run_kubectl "rollout status deployment/cicd-backend -n monitoring --timeout=120s" || true
        run_kubectl "rollout status deployment/cicd-frontend -n monitoring --timeout=120s" || true
        
        echo ""
        echo -e "${GREEN}✓ Full stack deployed successfully${NC}"
        MASTER_IP=$(get_private_ip 'node-0')
        echo -e "${YELLOW}Access URLs:${NC}"
        echo -e "  Frontend: ${GREEN}http://$MASTER_IP:30300${NC}"
        echo -e "  Backend:  ${GREEN}http://$MASTER_IP:30500${NC}"
        ;;

    scale-frontend)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No replica count specified${NC}"
            echo "Usage: $0 scale-frontend N"
            exit 1
        fi
        echo -e "${BLUE}Scaling frontend to $2 replicas...${NC}"
        run_kubectl "scale deployment/cicd-frontend --replicas=$2 -n monitoring"
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    scale-backend)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No replica count specified${NC}"
            echo "Usage: $0 scale-backend N"
            exit 1
        fi
        echo -e "${BLUE}Scaling backend to $2 replicas...${NC}"
        run_kubectl "scale deployment/cicd-backend --replicas=$2 -n monitoring"
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    restart-frontend)
        echo -e "${BLUE}Restarting frontend deployment...${NC}"
        run_kubectl "rollout restart deployment/cicd-frontend -n monitoring"
        echo -e "${GREEN}✓ Restart initiated${NC}"
        run_kubectl "rollout status deployment/cicd-frontend -n monitoring --timeout=120s" || true
        ;;

    restart-backend)
        echo -e "${BLUE}Restarting backend deployment...${NC}"
        run_kubectl "rollout restart deployment/cicd-backend -n monitoring"
        echo -e "${GREEN}✓ Restart initiated${NC}"
        run_kubectl "rollout status deployment/cicd-backend -n monitoring --timeout=120s" || true
        ;;

    logs-frontend)
        echo -e "${BLUE}Frontend logs (last 50 lines):${NC}"
        run_kubectl "logs -l app=cicd-frontend -n monitoring --tail=50"
        ;;

    logs-backend)
        echo -e "${BLUE}Backend logs (last 50 lines):${NC}"
        run_kubectl "logs -l app=cicd-backend -n monitoring --tail=50"
        ;;

    status-fullstack)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Full Stack Status${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        
        echo -e "\n${YELLOW}Backend:${NC}"
        run_kubectl "get deployment cicd-backend -n monitoring"
        run_kubectl "get pods -l app=cicd-backend -n monitoring"
        
        echo -e "\n${YELLOW}Frontend:${NC}"
        run_kubectl "get deployment cicd-frontend -n monitoring"
        run_kubectl "get pods -l app=cicd-frontend -n monitoring"
        
        echo -e "\n${YELLOW}Services:${NC}"
        run_kubectl "get svc cicd-backend cicd-frontend -n monitoring"
        
        MASTER_IP=$(get_private_ip 'node-0')
        echo -e "\n${YELLOW}Access URLs:${NC}"
        echo -e "  Frontend: ${GREEN}http://$MASTER_IP:30300${NC}"
        echo -e "  Backend:  ${GREEN}http://$MASTER_IP:30500${NC}"
        ;;

    delete-frontend)
        echo -e "${RED}Deleting frontend deployment...${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            run_kubectl "delete deployment cicd-frontend -n monitoring"
            run_kubectl "delete service cicd-frontend -n monitoring"
            echo -e "${GREEN}✓ Frontend deleted${NC}"
        else
            echo "Cancelled"
        fi
        ;;

    delete-backend)
        echo -e "${RED}Deleting backend deployment...${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            run_kubectl "delete deployment cicd-backend -n monitoring"
            run_kubectl "delete service cicd-backend -n monitoring"
            echo -e "${GREEN}✓ Backend deleted${NC}"
        else
            echo "Cancelled"
        fi
        ;;

    # ========================================================================
    # Deployment Commands
    # ========================================================================
    deploy)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Starting Full HA Kubernetes Deployment${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Architecture:${NC}"
        echo -e "  - 1 Load Balancer (HAProxy)"
        echo -e "  - 2 Master Nodes (Control Plane)"
        echo -e "  - 4 Worker Nodes"
        echo ""
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
        echo -e "${GREEN}✓ Deployment completed${NC}"
        ;;

    deploy-grafana)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Grafana${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        # Copy manifest to primary master
        ansible k8s_primary_master -i "$INVENTORY" -m copy \
            -a "src=$ANSIBLE_DIR/files/k8s/grafana-deployment.yml dest=/tmp/grafana-deployment.yml" -b

        # Apply manifest
        run_kubectl "apply -f /tmp/grafana-deployment.yml"

        echo -e "${GREEN}✓ Grafana deployment updated${NC}"
        echo -e "${YELLOW}Waiting for rollout...${NC}"
        run_kubectl "rollout status deployment/grafana -n monitoring --timeout=120s" || true

        echo ""
        echo -e "${GREEN}✓ Grafana deployed successfully${NC}"
        echo -e "${YELLOW}Access at:${NC} http://$(get_private_ip 'node-0'):30030"
        ;;

    # ========================================================================
    # Phased Deployment
    # ========================================================================
    phase1)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Phase 1: Load Balancer + Primary Master${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}This will:${NC}"
        echo -e "  1. Configure HAProxy load balancer"
        echo -e "  2. Prepare primary master node"
        echo -e "  3. Initialize Kubernetes control plane"
        echo -e "  4. Install Calico CNI"
        echo ""
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "phase1"
        echo -e "${GREEN}✓ Phase 1 completed${NC}"
        echo -e "${YELLOW}Next: Run '$0 phase2' to join secondary masters${NC}"
        ;;

    phase2)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Phase 2: Join Secondary Masters${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        # Check if join commands exist
        if [ ! -f "/tmp/k8s-join-commands/join-commands.sh" ]; then
            echo -e "${YELLOW}⚠️  Join commands not found. This may fail if Phase 1 was run more than 2 hours ago.${NC}"
            echo -e "${YELLOW}If Phase 2 fails, re-run Phase 1 or regenerate join commands on the primary master.${NC}"
            echo ""
        fi

        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "phase2"
        echo -e "${GREEN}✓ Phase 2 completed${NC}"
        echo -e "${YELLOW}Next: Run '$0 phase3' to join worker nodes${NC}"
        ;;

    phase3)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Phase 3: Join Worker Nodes${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "phase3"
        echo -e "${GREEN}✓ Phase 3 completed${NC}"
        echo -e "${YELLOW}Next: Run '$0 phase4' to deploy applications${NC}"
        ;;

    phase4)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Phase 4: Deploy Applications${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "phase4"
        echo -e "${GREEN}✓ Phase 4 completed${NC}"
        echo -e "${GREEN}✓ Full deployment completed!${NC}"
        ;;

    # ========================================================================
    # Granular Deployment
    # ========================================================================
    deploy-lb)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Load Balancer${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "loadbalancer"
        echo -e "${GREEN}✓ Load balancer deployment completed${NC}"
        ;;

    deploy-primary)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Primary Master${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "primary-master"
        echo -e "${GREEN}✓ Primary master deployment completed${NC}"
        ;;

    deploy-secondary)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Joining Secondary Masters${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "secondary-masters"
        echo -e "${GREEN}✓ Secondary masters joined${NC}"
        ;;

    deploy-workers)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Joining Worker Nodes${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "workers"
        echo -e "${GREEN}✓ Worker nodes joined${NC}"
        ;;

    deploy-apps)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Applications${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "apps"
        echo -e "${GREEN}✓ Application deployment completed${NC}"
        ;;

    deploy-cluster)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Kubernetes Cluster (No Apps)${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --skip-tags "apps"
        echo -e "${GREEN}✓ Cluster deployment completed${NC}"
        ;;

    # ========================================================================
    # Load Balancer Management
    # ========================================================================
    lb-status)
        echo -e "${BLUE}HAProxy Service Status:${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
            -a "systemctl status haproxy" -b 2>/dev/null | grep -v "CHANGED" || true
        ;;

    lb-stats)
        LB_IP=$(get_lb_ip)
        if [ -n "$LB_IP" ]; then
            echo -e "${CYAN}══════════════════════════════════════════${NC}"
            echo -e "${MAGENTA}HAProxy Statistics Dashboard${NC}"
            echo -e "${CYAN}══════════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}Stats URL:${NC}     ${GREEN}http://$LB_IP:8404${NC}"
            echo -e "${YELLOW}Username:${NC}      admin"
            echo -e "${YELLOW}Password:${NC}      admin123"
            echo ""
            echo -e "${YELLOW}Backend Servers:${NC}"
            echo "  - node-0 (192.168.56.10:6443)"
            echo "  - node-1 (192.168.56.11:6443)"
            echo ""
        else
            echo -e "${RED}Could not determine load balancer IP${NC}"
            echo "Check if load balancer VM is running: vagrant status lb-0"
        fi
        ;;

    lb-config)
        echo -e "${BLUE}HAProxy Configuration:${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
            -a "cat /etc/haproxy/haproxy.cfg" -b 2>/dev/null | grep -v "CHANGED" || true
        ;;

    lb-restart)
        echo -e "${BLUE}Restarting HAProxy...${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
            -a "systemctl restart haproxy" -b
        echo -e "${GREEN}✓ HAProxy restarted${NC}"
        ;;

    # ========================================================================
    # Kubectl Commands (with better error handling)
    # ========================================================================
    kubectl)
        shift
        if [ $# -eq 0 ]; then
            echo -e "${RED}Error: No kubectl arguments provided${NC}"
            echo "Usage: $0 kubectl <kubectl-args>"
            exit 1
        fi
        run_kubectl "$@" || exit 1
        ;;

    nodes)
        echo -e "${BLUE}Cluster Nodes Status:${NC}"
        run_kubectl "get nodes -o wide" || exit 1
        ;;

    pods)
        echo -e "${BLUE}Pods in monitoring namespace:${NC}"
        run_kubectl "get pods -n monitoring -o wide" || exit 1
        ;;

    services)
        echo -e "${BLUE}Services in monitoring namespace:${NC}"
        run_kubectl "get svc -n monitoring -o wide" || exit 1
        ;;

    deployments)
        echo -e "${BLUE}Deployments in monitoring namespace:${NC}"
        run_kubectl "get deployments -n monitoring" || exit 1
        ;;

    describe-pod)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No pod name specified${NC}"
            echo "Usage: $0 describe-pod POD_NAME"
            exit 1
        fi
        run_kubectl "describe pod $2 -n monitoring" || exit 1
        ;;

    logs-pod)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No pod name specified${NC}"
            echo "Usage: $0 logs-pod POD_NAME"
            exit 1
        fi
        run_kubectl "logs $2 -n monitoring --tail=50" || exit 1
        ;;

    # ========================================================================
    # Application Management
    # ========================================================================
    scale-app)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No replica count specified${NC}"
            echo "Usage: $0 scale-app N"
            exit 1
        fi
        echo -e "${BLUE}Scaling python-app to $2 replicas...${NC}"
        run_kubectl "scale deployment/python-app --replicas=$2 -n monitoring" || exit 1
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    scale-selenium)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No replica count specified${NC}"
            echo "Usage: $0 scale-selenium N"
            exit 1
        fi
        echo -e "${BLUE}Scaling selenium-chrome to $2 replicas...${NC}"
        run_kubectl "scale deployment/selenium-chrome --replicas=$2 -n monitoring" || exit 1
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    restart-app)
        echo -e "${BLUE}Restarting python-app deployment...${NC}"
        run_kubectl "rollout restart deployment/python-app -n monitoring" || exit 1
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-prometheus)
        echo -e "${BLUE}Restarting Prometheus deployment...${NC}"
        run_kubectl "rollout restart deployment/prometheus -n monitoring" || exit 1
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-grafana)
        echo -e "${BLUE}Restarting Grafana deployment...${NC}"
        run_kubectl "rollout restart deployment/grafana -n monitoring" || exit 1
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-selenium)
        echo -e "${BLUE}Restarting Selenium deployments...${NC}"
        run_kubectl "rollout restart deployment/selenium-hub -n monitoring" || exit 1
        run_kubectl "rollout restart deployment/selenium-chrome -n monitoring" || exit 1
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    # ========================================================================
    # Health & Status
    # ========================================================================
    health)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}HA Cluster Health Check${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        echo -e "\n${YELLOW}Load Balancer:${NC}"
        LB_IP=$(get_lb_ip)
        if [ -n "$LB_IP" ]; then
            if command -v nc &> /dev/null && nc -zv "$LB_IP" 6443 2>&1 | grep -q succeeded; then
                echo -e "  ${GREEN}✓${NC} HAProxy accessible at $LB_IP:6443"
            elif command -v telnet &> /dev/null; then
                if timeout 2 telnet "$LB_IP" 6443 2>&1 | grep -q Connected; then
                    echo -e "  ${GREEN}✓${NC} HAProxy accessible at $LB_IP:6443"
                else
                    echo -e "  ${RED}✗${NC} HAProxy not accessible"
                fi
            else
                echo -e "  ${YELLOW}?${NC} Cannot test (nc/telnet not available)"
            fi
        fi

        echo -e "\n${YELLOW}Control Plane:${NC}"
        run_kubectl "get nodes -l node-role.kubernetes.io/control-plane" || echo "  ${RED}✗${NC} Cannot access cluster"

        echo -e "\n${YELLOW}Worker Nodes:${NC}"
        run_kubectl "get nodes -l '!node-role.kubernetes.io/control-plane'" || echo "  ${RED}✗${NC} Cannot access cluster"

        echo -e "\n${YELLOW}Pod Status:${NC}"
        run_kubectl "get pods -n monitoring" || echo "  ${RED}✗${NC} Cannot access cluster"

        echo -e "\n${YELLOW}Unhealthy Pods (if any):${NC}"
        run_kubectl "get pods -n monitoring --field-selector=status.phase!=Running,status.phase!=Succeeded" 2>/dev/null || echo "  All pods healthy"

        echo ""
        ;;

    status)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Kubernetes HA Cluster Status${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        LB_IP=$(get_lb_ip)
        echo -e "\n${YELLOW}Load Balancer:${NC} $LB_IP"

        echo -e "\n${YELLOW}Nodes:${NC}"
        run_kubectl "get nodes -o wide" || echo "${RED}Cannot access cluster${NC}"

        echo -e "\n${YELLOW}Deployments:${NC}"
        run_kubectl "get deployments -n monitoring" || echo "${RED}Cannot access cluster${NC}"

        echo -e "\n${YELLOW}Services:${NC}"
        run_kubectl "get svc -n monitoring" || echo "${RED}Cannot access cluster${NC}"

        echo -e "\n${YELLOW}Pods:${NC}"
        run_kubectl "get pods -n monitoring -o wide" || echo "${RED}Cannot access cluster${NC}"

        echo ""
        ;;

    urls)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Service URLs (NodePort)${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        LB_IP=$(get_lb_ip)
        MASTER_IP=$(get_private_ip "node-0")

        echo -e "\n${YELLOW}🔧 Infrastructure:${NC}"
        if [ -n "$LB_IP" ]; then
            echo -e "   HAProxy Stats: ${GREEN}http://$LB_IP:8404${NC} (admin/admin123)"
            echo -e "   API Endpoint:  ${GREEN}https://$LB_IP:6443${NC}"
        else
            echo -e "   ${RED}Cannot determine load balancer IP${NC}"
        fi

        if [ -n "$MASTER_IP" ]; then
            echo -e "\n${YELLOW}📦 Application:${NC}"
            echo -e "   Frontend:      ${GREEN}http://$MASTER_IP:30300${NC}"
            echo -e "   Backend:       ${GREEN}http://$MASTER_IP:30500${NC}"
            echo -e "   Health Check:  ${GREEN}http://$MASTER_IP:30500/api/health${NC}"

            echo -e "\n${YELLOW}📊 Monitoring:${NC}"
            echo -e "   Prometheus:    ${GREEN}http://$MASTER_IP:30090${NC}"
            echo -e "   Grafana:       ${GREEN}http://$MASTER_IP:30030${NC} (admin/admin)"

            echo -e "\n${YELLOW}🧪 Testing:${NC}"
            echo -e "   Selenium Hub:  ${GREEN}http://$MASTER_IP:30444${NC}"
            echo -e "   Pushgateway:   ${GREEN}http://$MASTER_IP:30091${NC}"

            echo -e "\n${YELLOW}Note:${NC} Services accessible from any master or worker node"
        else
            echo -e "\n${RED}Cannot determine cluster IP${NC}"
        fi

        echo ""
        ;;

    metrics)
        echo -e "${BLUE}Node Resource Usage:${NC}"
        run_kubectl "top nodes" || echo "${RED}Metrics server may not be installed${NC}"

        echo -e "\n${BLUE}Pod Resource Usage:${NC}"
        run_kubectl "top pods -n monitoring" || echo "${RED}Metrics server may not be installed${NC}"
        ;;

    ha-test)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Testing HA Failover Capability${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        LB_IP=$(get_lb_ip)

        echo -e "\n${YELLOW}Step 1: Test API through Load Balancer${NC}"
        if command -v nc &> /dev/null && nc -zv "$LB_IP" 6443 2>&1 | grep -q succeeded; then
            echo -e "  ${GREEN}✓${NC} API accessible via LB ($LB_IP:6443)"
        else
            echo -e "  ${RED}✗${NC} API not accessible via LB"
            exit 1
        fi

        echo -e "\n${YELLOW}Step 2: Check all masters are ready${NC}"
        run_kubectl "get nodes -l node-role.kubernetes.io/control-plane"

        echo -e "\n${YELLOW}Step 3: HAProxy backend status${NC}"
        if command -v curl &> /dev/null; then
            curl -s "http://$LB_IP:8404" > /dev/null && echo -e "  ${GREEN}✓${NC} HAProxy stats accessible" || echo -e "  ${RED}✗${NC} HAProxy stats not accessible"
        else
            echo -e "  ${YELLOW}?${NC} curl not available for testing"
        fi

        echo -e "\n${YELLOW}Failover Test Instructions:${NC}"
        echo "  1. Run: vagrant halt node-0"
        echo "  2. Wait 10 seconds"
        echo "  3. Run: $0 nodes"
        echo "  4. Verify API still works through LB"
        echo "  5. Run: vagrant up node-0"
        echo ""
        ;;

    # ========================================================================
    # Testing
    # ========================================================================
    selenium-test)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Running Selenium Test${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        # Trigger the cronjob manually
        run_kubectl "create job --from=cronjob/selenium-test selenium-test-manual-\$(date +%s) -n monitoring" || exit 1

        echo -e "${GREEN}✓ Test job created${NC}"
        echo "View logs with: $0 kubectl logs -l job-name=selenium-test-manual-* -n monitoring"
        ;;

    selenium-metrics)
        echo -e "${BLUE}Fetching Selenium metrics from Pushgateway...${NC}"
        MASTER_IP=$(get_private_ip "node-0")
        if [ -n "$MASTER_IP" ]; then
            if command -v curl &> /dev/null; then
                curl -s "http://$MASTER_IP:30091/metrics" | grep selenium || echo "${YELLOW}No selenium metrics found${NC}"
            else
                echo -e "${RED}curl not available${NC}"
            fi
        else
            echo -e "${RED}Could not determine cluster IP${NC}"
        fi
        ;;

    # ========================================================================
    # Troubleshooting
    # ========================================================================
    logs-node)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No node specified${NC}"
            echo "Usage: $0 logs-node NODE_NAME"
            exit 1
        fi
        echo -e "${BLUE}Fetching kubelet logs from $2...${NC}"
        ansible "$2" -i "$INVENTORY" -m shell -a "journalctl -u kubelet -n 50" -b
        ;;

    logs-lb)
        echo -e "${BLUE}Fetching HAProxy logs...${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
            -a "journalctl -u haproxy -n 50" -b
        ;;

    debug-apiserver)
        echo -e "${BLUE}Debugging API Server on primary master...${NC}"
        echo ""
        echo -e "${YELLOW}1. Checking API server container:${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell \
            -a "crictl ps | grep kube-apiserver" -b 2>/dev/null || echo "Not running"

        echo ""
        echo -e "${YELLOW}2. Checking API server logs:${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell \
            -a "crictl logs \$(crictl ps -q --name kube-apiserver) 2>/dev/null | tail -50" -b 2>/dev/null || \
            echo "Container not found - checking static pod logs..."

        echo ""
        echo -e "${YELLOW}3. Checking kubelet logs:${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell \
            -a "journalctl -u kubelet --no-pager -n 30" -b

        echo ""
        echo -e "${YELLOW}4. Checking static pod manifests:${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell \
            -a "ls -la /etc/kubernetes/manifests/" -b

        echo ""
        echo -e "${YELLOW}5. Checking if API is listening:${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell \
            -a "netstat -tlnp | grep 6443 || ss -tlnp | grep 6443" -b
        ;;

    debug-cluster)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Cluster Debugging Information${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        echo ""
        echo -e "${YELLOW}=== Load Balancer ===${NC}"
        ansible k8s_loadbalancer -i "$INVENTORY" -m shell -a "systemctl status haproxy | head -10" -b 2>/dev/null || true

        echo ""
        echo -e "${YELLOW}=== Primary Master - Containerd ===${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell -a "systemctl status containerd | head -5" -b

        echo ""
        echo -e "${YELLOW}=== Primary Master - Kubelet ===${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell -a "systemctl status kubelet | head -10" -b

        echo ""
        echo -e "${YELLOW}=== Primary Master - Control Plane Pods ===${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell -a "crictl pods" -b 2>/dev/null || true

        echo ""
        echo -e "${YELLOW}=== Primary Master - Running Containers ===${NC}"
        ansible k8s_primary_master -i "$INVENTORY" -m shell -a "crictl ps" -b 2>/dev/null || true
        ;;

    drain)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No node specified${NC}"
            echo "Usage: $0 drain NODE_NAME"
            exit 1
        fi
        echo -e "${YELLOW}Draining node $2...${NC}"
        run_kubectl "drain $2 --ignore-daemonsets --delete-emptydir-data" || exit 1
        echo -e "${GREEN}✓ Node drained${NC}"
        ;;

    uncordon)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No node specified${NC}"
            echo "Usage: $0 uncordon NODE_NAME"
            exit 1
        fi
        echo -e "${BLUE}Uncordoning node $2...${NC}"
        run_kubectl "uncordon $2" || exit 1
        echo -e "${GREEN}✓ Node marked as schedulable${NC}"
        ;;

    top-nodes)
        echo -e "${BLUE}Node Resource Usage:${NC}"
        run_kubectl "top nodes" || echo "${RED}Metrics server may not be installed${NC}"
        ;;

    top-pods)
        echo -e "${BLUE}Pod Resource Usage:${NC}"
        run_kubectl "top pods -n monitoring" || echo "${RED}Metrics server may not be installed${NC}"
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
