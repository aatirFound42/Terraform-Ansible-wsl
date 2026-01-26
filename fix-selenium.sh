#!/bin/bash
# Quick fix - just copy and paste this entire block

echo "🔧 Fixing Selenium Grid..."

# Add missing ports to Hub service
echo "📝 Adding event bus ports to Hub service..."
./run-ansible-k8s.sh kubectl patch service selenium-hub -n monitoring --type='json' -p='[
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "publish", "port": 4442, "targetPort": 4442, "protocol": "TCP"}},
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "subscribe", "port": 4443, "targetPort": 4443, "protocol": "TCP"}}
]'

# Restart Hub
echo "🔄 Restarting Selenium Hub..."
./run-ansible-k8s.sh kubectl rollout restart deployment/selenium-hub -n monitoring

# Wait for Hub
echo "⏳ Waiting for Hub to restart..."
sleep 20

# Force Chrome pods to reconnect
echo "🔄 Restarting Chrome nodes..."
./run-ansible-k8s.sh kubectl delete pods -l app=selenium-chrome -n monitoring

# Wait for Chrome pods
echo "⏳ Waiting for Chrome nodes to reconnect..."
sleep 40

# Verify
echo ""
echo "🔍 Verification:"
echo ""
echo "Pods:"
./run-ansible-k8s.sh kubectl get pods -n monitoring | grep selenium

echo ""
echo "Grid Status:"
curl -s http://192.168.56.10:30444/status | jq '{nodes: (.value.nodes | length), ready: .value.ready}'

echo ""
echo "✅ Done! Check Grid UI at: http://192.168.56.10:30444/ui"
