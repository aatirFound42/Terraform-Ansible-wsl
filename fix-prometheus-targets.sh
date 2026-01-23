#!/bin/bash
# fix-prometheus-targets.sh - Fix Prometheus target configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="$SCRIPT_DIR/ansible/inventory.ini"

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Fixing Prometheus Target Configuration${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Step 1: Check current Prometheus config on the VM
echo -e "\n${YELLOW}Step 1: Checking current Prometheus configuration...${NC}"
ansible prometheus_node -i "$INVENTORY" -m shell -a "cat /opt/monitoring/prometheus.yml"

# Step 2: Show what IPs we should be using
echo -e "\n${YELLOW}Step 2: Gathering correct IPs from inventory...${NC}"

echo -e "\n${BLUE}Application VMs (should have these IPs):${NC}"
for host in $(ansible app_nodes -i "$INVENTORY" --list-hosts | grep -v "hosts" | xargs); do
    IP=$(grep "^$host " "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+' || echo "NOT FOUND")
    echo -e "  ${GREEN}$host${NC}: $IP"
done

echo -e "\n${BLUE}All VMs for node-exporter (should have these IPs):${NC}"
for host in $(ansible all_vms -i "$INVENTORY" --list-hosts | grep -v "hosts" | xargs); do
    IP=$(grep "^$host " "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+' || echo "NOT FOUND")
    echo -e "  ${GREEN}$host${NC}: $IP"
done

# Step 3: Regenerate Prometheus config
echo -e "\n${YELLOW}Step 3: Regenerating Prometheus configuration...${NC}"
ansible-playbook -i "$INVENTORY" "$SCRIPT_DIR/ansible/playbook.yml" --limit prometheus_node --tags never 2>/dev/null || \
    ansible prometheus_node -i "$INVENTORY" -m template -a "src=$SCRIPT_DIR/ansible/files/prometheus.yml.j2 dest=/opt/monitoring/prometheus.yml mode=0644"

# Step 4: Show the new config
echo -e "\n${YELLOW}Step 4: New Prometheus configuration:${NC}"
ansible prometheus_node -i "$INVENTORY" -m shell -a "cat /opt/monitoring/prometheus.yml"

# Step 5: Restart Prometheus
echo -e "\n${YELLOW}Step 5: Restarting Prometheus...${NC}"
ansible prometheus_node -i "$INVENTORY" -m shell -a "docker restart prometheus"

echo -e "${GREEN}✓ Prometheus restarted${NC}"

# Step 6: Wait for Prometheus to be ready
echo -e "\n${YELLOW}Step 6: Waiting for Prometheus to be ready...${NC}"
sleep 5

PROM_IP=$(ansible prometheus_node -i "$INVENTORY" -m shell -a "hostname -I | awk '{print \$1}'" 2>/dev/null | grep -v "CHANGED" | grep -E '^[0-9]' | head -1 | xargs)

if curl -s "http://$PROM_IP:9090/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Prometheus is healthy${NC}"
else
    echo -e "${RED}✗ Prometheus is not responding yet, wait a few more seconds${NC}"
fi

# Step 7: Check targets
echo -e "\n${YELLOW}Step 7: Checking targets status (wait 15 seconds for first scrape)...${NC}"
sleep 15

if command -v jq &> /dev/null; then
    TARGETS=$(curl -s "http://$PROM_IP:9090/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job): \(.labels.instance) - \(.health)"')
    
    echo -e "\n${BLUE}Current targets:${NC}"
    echo "$TARGETS" | while read -r line; do
        if [[ $line == *"up"* ]]; then
            echo -e "  ${GREEN}✓${NC} $line"
        else
            echo -e "  ${RED}✗${NC} $line"
        fi
    done
    
    TOTAL=$(echo "$TARGETS" | wc -l)
    UP=$(echo "$TARGETS" | grep -c "up" || echo "0")
    
    echo -e "\n${CYAN}Summary: ${GREEN}$UP${NC}/${YELLOW}$TOTAL${NC} targets UP"
    
    if [ "$UP" -ge 9 ]; then
        echo -e "${GREEN}✓✓✓ All targets are UP!${NC}"
    else
        echo -e "${YELLOW}⚠ Expected 9 targets (1 prometheus + 3 apps + 5 node-exporters)${NC}"
    fi
else
    echo -e "${YELLOW}Install jq for detailed target info: sudo apt install jq${NC}"
    echo -e "Or check manually at: ${BLUE}http://$PROM_IP:9090/targets${NC}"
fi

echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "\n${BLUE}Access Prometheus:${NC} http://$PROM_IP:9090/targets"
echo -e "${BLUE}Refresh the page to see updated targets${NC}"
echo ""
