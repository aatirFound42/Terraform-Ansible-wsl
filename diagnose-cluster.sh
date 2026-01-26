#!/bin/bash
# diagnose-cluster.sh - Diagnose Kubernetes cluster connectivity issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Kubernetes Cluster Diagnostics${NC}"
echo ""

# Test 1: Check if VMs are reachable
echo -e "${YELLOW}Test 1: VM Connectivity${NC}"
if ansible all_vms -i ansible/inventory.ini -m ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ All VMs are reachable${NC}"
else
    echo -e "${RED}❌ Some VMs are not reachable${NC}"
    echo "Run: vagrant status"
    exit 1
fi
echo ""

# Test 2: Check HAProxy
echo -e "${YELLOW}Test 2: HAProxy Status${NC}"
LB_STATUS=$(ansible k8s_loadbalancer -i ansible/inventory.ini -m shell \
    -a "systemctl is-active haproxy" -b 2>/dev/null | grep -v "CHANGED" | tail -1)

if [ "$LB_STATUS" = "active" ]; then
    echo -e "${GREEN}✅ HAProxy is running${NC}"
else
    echo -e "${RED}❌ HAProxy is not running${NC}"
    echo "Attempting to start HAProxy..."
    ansible k8s_loadbalancer -i ansible/inventory.ini -m shell \
        -a "systemctl restart haproxy" -b
    sleep 5
fi
echo ""

# Test 3: Check kubelet on masters
echo -e "${YELLOW}Test 3: Kubelet Status on Masters${NC}"
ansible k8s_masters -i ansible/inventory.ini -m shell \
    -a "systemctl is-active kubelet" -b 2>/dev/null | grep -E "(active|CHANGED)"
echo ""

# Test 4: Check if API server is listening
echo -e "${YELLOW}Test 4: API Server Port Check${NC}"
LB_IP=$(grep -A2 "^\[k8s_loadbalancer\]" ansible/inventory.ini | \
    grep "ansible_host" | \
    sed -n 's/.*ansible_host=\([0-9.]*\).*/\1/p' | head -1)

if [ -n "$LB_IP" ]; then
    echo "Testing connection to $LB_IP:6443..."
    if timeout 5 bash -c "echo > /dev/tcp/$LB_IP/6443" 2>/dev/null; then
        echo -e "${GREEN}✅ API server is listening on $LB_IP:6443${NC}"
    else
        echo -e "${RED}❌ Cannot reach API server on $LB_IP:6443${NC}"
    fi
else
    echo -e "${RED}❌ Cannot determine load balancer IP${NC}"
fi
echo ""

# Test 5: Check control plane pods
echo -e "${YELLOW}Test 5: Control Plane Pods${NC}"
ansible k8s_primary_master -i ansible/inventory.ini -m shell \
    -a "crictl pods | grep kube-system | wc -l" -b 2>/dev/null | \
    grep -v "CHANGED" | tail -1 | \
    { read count; 
      if [ "$count" -gt 0 ]; then 
          echo -e "${GREEN}✅ Found $count control plane pods${NC}"; 
      else 
          echo -e "${RED}❌ No control plane pods found${NC}"; 
      fi
    }
echo ""

# Test 6: Try kubectl from master
echo -e "${YELLOW}Test 6: kubectl from Primary Master${NC}"
if ansible k8s_primary_master -i ansible/inventory.ini -m shell \
    -a "kubectl get nodes --request-timeout=5s" -b 2>/dev/null | \
    grep -q "Ready"; then
    echo -e "${GREEN}✅ kubectl works on primary master${NC}"
    echo ""
    ansible k8s_primary_master -i ansible/inventory.ini -m shell \
        -a "kubectl get nodes" -b 2>/dev/null | grep -v "CHANGED"
else
    echo -e "${RED}❌ kubectl timeout on primary master${NC}"
    echo ""
    echo -e "${YELLOW}Suggested fixes:${NC}"
    echo "1. Restart kubelet: ansible k8s_primary_master -i ansible/inventory.ini -m shell -a 'systemctl restart kubelet' -b"
    echo "2. Check logs: ssh to master and run: sudo journalctl -u kubelet -n 50"
    echo "3. Restart HAProxy: ansible k8s_loadbalancer -i ansible/inventory.ini -m shell -a 'systemctl restart haproxy' -b"
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Diagnostic Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "If kubectl is timing out, try these fixes in order:"
echo ""
echo "1. Restart services:"
echo "   ./run-ansible-k8s.sh lb-restart"
echo "   ansible k8s_masters -i ansible/inventory.ini -m shell -a 'systemctl restart kubelet' -b"
echo ""
echo "2. SSH to master directly:"
echo "   ssh vagrant@$LB_IP"
echo "   sudo kubectl get nodes"
echo ""
echo "3. If nothing works, check API server logs:"
echo "   ssh vagrant@$LB_IP"
echo "   sudo journalctl -u kubelet -n 100"
echo "   sudo crictl logs \$(sudo crictl ps -q --name kube-apiserver)"
