#!/bin/bash
# run-ansible-k8s.sh - Kubernetes HA Multi-Master Deployment Tool
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
    echo -e "  ${GREEN}deploy${NC}            - Full HA Kubernetes cluster deployment"
    echo -e "  ${GREEN}deploy-lb${NC}         - Deploy load balancer only"
    echo -e "  ${GREEN}deploy-cluster${NC}    - Deploy K8s cluster only (no apps)"
    echo -e "  ${GREEN}deploy-apps${NC}       - Deploy applications to existing cluster"
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
    echo -e "  ${GREEN}drain${NC} NODE        - Drain a node for maintenance"
    echo -e "  ${GREEN}uncordon${NC} NODE     - Mark node as schedulable"
    echo -e "  ${GREEN}top-nodes${NC}         - Show node resource usage"
    echo -e "  ${GREEN}top-pods${NC}          - Show pod resource usage"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 deploy                    # Full HA deployment"
    echo "  $0 lb-status                 # Check load balancer"
    echo "  $0 nodes                     # Show cluster nodes"
    echo "  $0 scale-app 5               # Scale app to 5 replicas"
    echo "  $0 kubectl get pods -A       # Run custom kubectl command"
    echo "  $0 ha-test                   # Test failover"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    exit 1
}

# Run kubectl on primary master
run_kubectl() {
    ansible k8s_primary_master -i "$INVENTORY" -m shell \
        -a "kubectl $*" \
        -e "ansible_become=yes" 2>/dev/null | grep -v "CHANGED" | grep -v "rc=0" || true
}

# Get private IP (more robust - searches all interfaces)
get_private_ip() {
    local host="$1"
    ansible "$host" -i "$INVENTORY" -m shell \
        -a "hostname -I | tr ' ' '\n' | grep -E '^192\.168\.56\.' | head -1" 2>/dev/null \
        | grep -v "CHANGED" | grep -E "192\.168\.56\." | tail -1 | xargs
}

# Get load balancer IP (from inventory directly for reliability)
get_lb_ip() {
    # Try to get from running node first
    local ip=$(ansible k8s_loadbalancer -i "$INVENTORY" -m shell \
        -a "hostname -I | tr ' ' '\n' | grep -E '^192\.168\.56\.' | head -1" 2>/dev/null \
        | grep -v "CHANGED" | grep -E "192\.168\.56\." | tail -1 | xargs)
    
    # Fallback to inventory file
    if [ -z "$ip" ]; then
        ip=$(grep -A1 "^\[k8s_loadbalancer\]" "$INVENTORY" | grep "ansible_host" | awk '{print $2}' | cut -d= -f2)
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
    # Deployment Commands
    # ========================================================================
    deploy)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Starting Full HA Kubernetes Deployment${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Architecture:${NC}"
        echo -e "  - 1 Load Balancer (HAProxy)"
        echo -e "  - 2 Master Nodes (Control Plane)"
        echo -e "  - 5 Worker Nodes"
        echo ""
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
        echo -e "${GREEN}✓ Deployment completed${NC}"
        ;;

    deploy-lb)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Load Balancer${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --limit k8s_loadbalancer
        echo -e "${GREEN}✓ Load balancer deployment completed${NC}"
        ;;

    deploy-cluster)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Kubernetes Cluster${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "cluster"
        echo -e "${GREEN}✓ Cluster deployment completed${NC}"
        ;;

    deploy-apps)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Deploying Applications${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --tags "apps"
        echo -e "${GREEN}✓ Application deployment completed${NC}"
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
    # Kubectl Commands
    # ========================================================================
    kubectl)
        shift
        run_kubectl "$@"
        ;;

    nodes)
        echo -e "${BLUE}Cluster Nodes Status:${NC}"
        run_kubectl "get nodes -o wide"
        ;;

    pods)
        echo -e "${BLUE}Pods in monitoring namespace:${NC}"
        run_kubectl "get pods -n monitoring -o wide"
        ;;

    services)
        echo -e "${BLUE}Services in monitoring namespace:${NC}"
        run_kubectl "get svc -n monitoring -o wide"
        ;;

    deployments)
        echo -e "${BLUE}Deployments in monitoring namespace:${NC}"
        run_kubectl "get deployments -n monitoring"
        ;;

    describe-pod)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No pod name specified${NC}"
            echo "Usage: $0 describe-pod POD_NAME"
            exit 1
        fi
        run_kubectl "describe pod $2 -n monitoring"
        ;;

    logs-pod)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No pod name specified${NC}"
            echo "Usage: $0 logs-pod POD_NAME"
            exit 1
        fi
        run_kubectl "logs $2 -n monitoring --tail=50"
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
        run_kubectl "scale deployment/python-app --replicas=$2 -n monitoring"
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    scale-selenium)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No replica count specified${NC}"
            echo "Usage: $0 scale-selenium N"
            exit 1
        fi
        echo -e "${BLUE}Scaling selenium-chrome to $2 replicas...${NC}"
        run_kubectl "scale deployment/selenium-chrome --replicas=$2 -n monitoring"
        echo -e "${GREEN}✓ Scaling initiated${NC}"
        ;;

    restart-app)
        echo -e "${BLUE}Restarting python-app deployment...${NC}"
        run_kubectl "rollout restart deployment/python-app -n monitoring"
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-prometheus)
        echo -e "${BLUE}Restarting Prometheus deployment...${NC}"
        run_kubectl "rollout restart deployment/prometheus -n monitoring"
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-grafana)
        echo -e "${BLUE}Restarting Grafana deployment...${NC}"
        run_kubectl "rollout restart deployment/grafana -n monitoring"
        echo -e "${GREEN}✓ Restart initiated${NC}"
        ;;

    restart-selenium)
        echo -e "${BLUE}Restarting Selenium deployments...${NC}"
        run_kubectl "rollout restart deployment/selenium-hub -n monitoring"
        run_kubectl "rollout restart deployment/selenium-chrome -n monitoring"
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
            if nc -zv "$LB_IP" 6443 2>&1 | grep -q succeeded; then
                echo -e "  ${GREEN}✓${NC} HAProxy accessible at $LB_IP:6443"
            else
                echo -e "  ${RED}✗${NC} HAProxy not accessible"
            fi
        fi

        echo -e "\n${YELLOW}Control Plane:${NC}"
        run_kubectl "get nodes -l node-role.kubernetes.io/control-plane"

        echo -e "\n${YELLOW}Worker Nodes:${NC}"
        run_kubectl "get nodes -l '!node-role.kubernetes.io/control-plane'"

        echo -e "\n${YELLOW}Pod Status:${NC}"
        run_kubectl "get pods -n monitoring"

        echo -e "\n${YELLOW}Unhealthy Pods (if any):${NC}"
        run_kubectl "get pods -n monitoring --field-selector=status.phase!=Running" || echo "  All pods healthy"

        echo ""
        ;;

    status)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Kubernetes HA Cluster Status${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        LB_IP=$(get_lb_ip)
        echo -e "\n${YELLOW}Load Balancer:${NC} $LB_IP"

        echo -e "\n${YELLOW}Nodes:${NC}"
        run_kubectl "get nodes -o wide"

        echo -e "\n${YELLOW}Deployments:${NC}"
        run_kubectl "get deployments -n monitoring"

        echo -e "\n${YELLOW}Services:${NC}"
        run_kubectl "get svc -n monitoring"

        echo -e "\n${YELLOW}Pods:${NC}"
        run_kubectl "get pods -n monitoring -o wide"

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
        fi

        if [ -n "$MASTER_IP" ]; then
            echo -e "\n${YELLOW}📦 Application:${NC}"
            echo -e "   Python App:    ${GREEN}http://$MASTER_IP:30500${NC}"
            echo -e "   Health Check:  http://$MASTER_IP:30500/api/health"

            echo -e "\n${YELLOW}📊 Monitoring:${NC}"
            echo -e "   Prometheus:    ${GREEN}http://$MASTER_IP:30090${NC}"
            echo -e "   Grafana:       ${GREEN}http://$MASTER_IP:30300${NC} (admin/admin)"

            echo -e "\n${YELLOW}🧪 Testing:${NC}"
            echo -e "   Selenium Hub:  ${GREEN}http://$MASTER_IP:30444${NC}"
            echo -e "   Pushgateway:   ${GREEN}http://$MASTER_IP:30091${NC}"

            echo -e "\n${YELLOW}Note:${NC} Services accessible from any master or worker node"
        else
            echo -e "${RED}Could not determine cluster IP${NC}"
        fi

        echo ""
        ;;

    metrics)
        echo -e "${BLUE}Node Resource Usage:${NC}"
        run_kubectl "top nodes"

        echo -e "\n${BLUE}Pod Resource Usage:${NC}"
        run_kubectl "top pods -n monitoring"
        ;;

    ha-test)
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}Testing HA Failover Capability${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"

        LB_IP=$(get_lb_ip)

        echo -e "\n${YELLOW}Step 1: Test API through Load Balancer${NC}"
        if nc -zv "$LB_IP" 6443 2>&1 | grep -q succeeded; then
            echo -e "  ${GREEN}✓${NC} API accessible via LB ($LB_IP:6443)"
        else
            echo -e "  ${RED}✗${NC} API not accessible via LB"
            exit 1
        fi

        echo -e "\n${YELLOW}Step 2: Check all masters are ready${NC}"
        run_kubectl "get nodes -l node-role.kubernetes.io/control-plane"

        echo -e "\n${YELLOW}Step 3: HAProxy backend status${NC}"
        curl -s "http://$LB_IP:8404" > /dev/null && echo -e "  ${GREEN}✓${NC} HAProxy stats accessible" || echo -e "  ${RED}✗${NC} HAProxy stats not accessible"

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
        run_kubectl "create job --from=cronjob/selenium-test selenium-test-manual-\$(date +%s) -n monitoring"

        echo -e "${GREEN}✓ Test job created${NC}"
        echo "View logs with: $0 kubectl logs -l job-name=selenium-test-manual-* -n monitoring"
        ;;

    selenium-metrics)
        echo -e "${BLUE}Fetching Selenium metrics from Pushgateway...${NC}"
        MASTER_IP=$(get_private_ip "node-0")
        if [ -n "$MASTER_IP" ]; then
            curl -s "http://$MASTER_IP:30091/metrics" | grep selenium
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

    drain)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No node specified${NC}"
            echo "Usage: $0 drain NODE_NAME"
            exit 1
        fi
        echo -e "${YELLOW}Draining node $2...${NC}"
        run_kubectl "drain $2 --ignore-daemonsets --delete-emptydir-data"
        echo -e "${GREEN}✓ Node drained${NC}"
        ;;

    uncordon)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: No node specified${NC}"
            echo "Usage: $0 uncordon NODE_NAME"
            exit 1
        fi
        echo -e "${BLUE}Uncordoning node $2...${NC}"
        run_kubectl "uncordon $2"
        echo -e "${GREEN}✓ Node marked as schedulable${NC}"
        ;;

    top-nodes)
        echo -e "${BLUE}Node Resource Usage:${NC}"
        run_kubectl "top nodes"
        ;;

    top-pods)
        echo -e "${BLUE}Pod Resource Usage:${NC}"
        run_kubectl "top pods -n monitoring"
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
