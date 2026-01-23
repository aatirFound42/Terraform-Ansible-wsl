#!/bin/bash
# direct-fix-prometheus.sh - Directly fix Prometheus config with correct IPs

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
echo -e "${BLUE}Direct Prometheus Configuration Fix${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Get IPs from inventory
echo -e "\n${YELLOW}Getting IPs from inventory...${NC}"

APP_IPS=(
    $(grep "node-0" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-1" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-2" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
)

ALL_IPS=(
    $(grep "node-0" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-1" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-2" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-3" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
    $(grep "node-4" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')
)

echo -e "${GREEN}Application IPs:${NC} ${APP_IPS[@]}"
echo -e "${GREEN}All VMs IPs:${NC} ${ALL_IPS[@]}"

# Create new Prometheus config
echo -e "\n${YELLOW}Creating new Prometheus configuration...${NC}"

cat > /tmp/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Application VMs
  - job_name: 'python-app'
    metrics_path: /metrics
    static_configs:
      - targets:
        - '${APP_IPS[0]}:5000'
        - '${APP_IPS[1]}:5000'
        - '${APP_IPS[2]}:5000'

  # Node Exporters on all VMs
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '${ALL_IPS[0]}:9100'
        - '${ALL_IPS[1]}:9100'
        - '${ALL_IPS[2]}:9100'
        - '${ALL_IPS[3]}:9100'
        - '${ALL_IPS[4]}:9100'
        labels:
          group: 'infrastructure'
EOF

echo -e "\n${BLUE}New configuration:${NC}"
cat /tmp/prometheus.yml

# Copy to Prometheus VM
echo -e "\n${YELLOW}Copying configuration to Prometheus VM...${NC}"
ansible prometheus_node -i "$INVENTORY" -m copy -a "src=/tmp/prometheus.yml dest=/opt/monitoring/prometheus.yml mode=0644"

# Verify it was copied
echo -e "\n${YELLOW}Verifying configuration on Prometheus VM...${NC}"
ansible prometheus_node -i "$INVENTORY" -m shell -a "cat /opt/monitoring/prometheus.yml"

# Restart Prometheus
echo -e "\n${YELLOW}Restarting Prometheus container...${NC}"
ansible prometheus_node -i "$INVENTORY" -m shell -a "docker restart prometheus"

echo -e "${GREEN}✓ Prometheus restarted${NC}"

# Wait for Prometheus
echo -e "\n${YELLOW}Waiting for Prometheus to start (10 seconds)...${NC}"
sleep 10

# Get Prometheus IP
PROM_IP=$(grep "node-3" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')

echo -e "\n${BLUE}Testing Prometheus health...${NC}"
if curl -s "http://$PROM_IP:9090/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Prometheus is healthy${NC}"
else
    echo -e "${RED}✗ Prometheus not responding, checking logs...${NC}"
    ansible prometheus_node -i "$INVENTORY" -m shell -a "docker logs prometheus --tail 20"
    exit 1
fi

# Check targets after first scrape
echo -e "\n${YELLOW}Waiting for first scrape (15 seconds)...${NC}"
sleep 15

echo -e "\n${BLUE}Checking targets...${NC}"
curl -s "http://$PROM_IP:9090/api/v1/targets" > /tmp/targets.json

if command -v jq &> /dev/null; then
    TOTAL=$(jq '.data.activeTargets | length' /tmp/targets.json)
    UP=$(jq '[.data.activeTargets[] | select(.health=="up")] | length' /tmp/targets.json)
    
    echo -e "\n${CYAN}Targets Summary:${NC}"
    jq -r '.data.activeTargets[] | "\(.labels.job): \(.labels.instance) - \(.health)"' /tmp/targets.json | while read -r line; do
        if [[ $line == *"up"* ]]; then
            echo -e "  ${GREEN}✓${NC} $line"
        else
            echo -e "  ${RED}✗${NC} $line"
        fi
    done
    
    echo -e "\n${CYAN}Total: ${GREEN}$UP${NC}/${YELLOW}$TOTAL${NC} targets UP${NC}"
    
    if [ "$TOTAL" -eq 9 ] && [ "$UP" -eq 9 ]; then
        echo -e "${GREEN}✓✓✓ Perfect! All 9 targets are UP!${NC}"
    elif [ "$TOTAL" -eq 9 ]; then
        echo -e "${YELLOW}⚠ All targets configured but some are DOWN${NC}"
    else
        echo -e "${RED}✗ Expected 9 targets, got $TOTAL${NC}"
    fi
else
    echo -e "${YELLOW}Install jq for detailed output: sudo apt install jq${NC}"
    cat /tmp/targets.json
fi

echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "\n${BLUE}Prometheus Targets:${NC} http://$PROM_IP:9090/targets"
echo -e "${BLUE}Refresh your browser to see all targets${NC}"
echo ""

# Cleanup
rm -f /tmp/prometheus.yml /tmp/targets.json
