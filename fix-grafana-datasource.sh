#!/bin/bash
# fix-grafana-datasource.sh - Fix Grafana datasource to use correct Prometheus IP

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
echo -e "${BLUE}Fixing Grafana Datasource Configuration${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Get Prometheus IP from inventory
echo -e "\n${YELLOW}Getting Prometheus IP from inventory...${NC}"
PROM_IP=$(grep "node-3" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')

if [ -z "$PROM_IP" ]; then
    echo -e "${RED}✗ Could not get Prometheus IP from inventory${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prometheus IP: $PROM_IP${NC}"

# Get Grafana IP
echo -e "\n${YELLOW}Getting Grafana IP from inventory...${NC}"
GRAF_IP=$(grep "node-4" "$INVENTORY" | grep -oP 'ansible_host=\K[^ ]+')

if [ -z "$GRAF_IP" ]; then
    echo -e "${RED}✗ Could not get Grafana IP from inventory${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Grafana IP: $GRAF_IP${NC}"

# Check current datasource config
echo -e "\n${YELLOW}Current Grafana datasource configuration:${NC}"
ansible grafana_node -i "$INVENTORY" -m shell -a "cat /opt/monitoring/grafana/datasources/datasource.yml"

# Create new datasource config
echo -e "\n${YELLOW}Creating new datasource configuration...${NC}"

cat > /tmp/datasource.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://$PROM_IP:9090
    isDefault: true
    editable: true
EOF

echo -e "\n${BLUE}New datasource configuration:${NC}"
cat /tmp/datasource.yml

# Copy to Grafana VM
echo -e "\n${YELLOW}Copying configuration to Grafana VM...${NC}"
ansible grafana_node -i "$INVENTORY" -m copy -a "src=/tmp/datasource.yml dest=/opt/monitoring/grafana/datasources/datasource.yml mode=0644"

# Verify it was copied
echo -e "\n${YELLOW}Verifying configuration on Grafana VM...${NC}"
ansible grafana_node -i "$INVENTORY" -m shell -a "cat /opt/monitoring/grafana/datasources/datasource.yml"

# Restart Grafana
echo -e "\n${YELLOW}Restarting Grafana container...${NC}"
ansible grafana_node -i "$INVENTORY" -m shell -a "docker restart grafana"

echo -e "${GREEN}✓ Grafana restarted${NC}"

# Wait for Grafana
echo -e "\n${YELLOW}Waiting for Grafana to start (10 seconds)...${NC}"
sleep 10

# Check Grafana health
echo -e "\n${BLUE}Testing Grafana health...${NC}"
if curl -s "http://$GRAF_IP:3000/api/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Grafana is healthy${NC}"
else
    echo -e "${RED}✗ Grafana not responding, checking logs...${NC}"
    ansible grafana_node -i "$INVENTORY" -m shell -a "docker logs grafana --tail 20"
    exit 1
fi

# Test if Grafana can reach Prometheus
echo -e "\n${YELLOW}Testing if Grafana can reach Prometheus...${NC}"
if ansible grafana_node -i "$INVENTORY" -m shell -a "curl -s http://$PROM_IP:9090/-/healthy" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Grafana can reach Prometheus${NC}"
else
    echo -e "${RED}✗ Grafana cannot reach Prometheus${NC}"
    echo -e "${YELLOW}Checking network connectivity...${NC}"
    ansible grafana_node -i "$INVENTORY" -m shell -a "ping -c 3 $PROM_IP"
fi

# Test Prometheus API from Grafana
echo -e "\n${YELLOW}Testing Prometheus API query from Grafana VM...${NC}"
TEST_RESULT=$(ansible grafana_node -i "$INVENTORY" -m shell -a "curl -s http://$PROM_IP:9090/api/v1/query?query=up | head -20" 2>/dev/null | grep -v "CHANGED")

if echo "$TEST_RESULT" | grep -q "success"; then
    echo -e "${GREEN}✓ Prometheus API is responding correctly${NC}"
else
    echo -e "${RED}✗ Prometheus API query failed${NC}"
    echo "$TEST_RESULT"
fi

echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  1. Open Grafana: ${GREEN}http://$GRAF_IP:3000${NC}"
echo -e "  2. Login with: ${GREEN}admin / admin${NC}"
echo -e "  3. Go to: ${CYAN}Connections → Data Sources → Prometheus${NC}"
echo -e "  4. Click: ${CYAN}Save & Test${NC}"
echo -e "  5. You should see: ${GREEN}✅ Data source is working${NC}"
echo ""
echo -e "${BLUE}If it still fails, wait 30 seconds and refresh the page${NC}"
echo ""

# Cleanup
rm -f /tmp/datasource.yml
