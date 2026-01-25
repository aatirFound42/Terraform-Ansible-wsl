#!/bin/bash
set -e

echo "🚀 Starting Kubernetes Deployment..."

# Phase 1: Storage
echo "📦 Phase 1: Installing Longhorn Storage..."
cd ../../k8s-manifests/storage/longhorn
./install.sh
cd -

# Phase 2: Networking
echo "🌐 Phase 2: Installing MetalLB..."
cd ../../k8s-manifests/networking/metallb
./install.sh
cd -

echo "🌐 Phase 2: Installing Ingress Controller..."
cd ../../k8s-manifests/networking/ingress-nginx
./install.sh
cd -

# Phase 3: Applications
echo "🐍 Phase 3: Deploying Flask API..."
kubectl apply -k ../../k8s-manifests/applications/flask-api/

# Phase 4: Monitoring
echo "📊 Phase 4: Installing Prometheus Stack..."
cd ../../k8s-manifests/monitoring/prometheus-stack
./install.sh
cd -

echo "📊 Phase 4: Applying Monitoring Ingress..."
kubectl apply -f ../../k8s-manifests/monitoring/ingress/

# Phase 5: Testing
echo "🧪 Phase 5: Deploying Selenium Testing..."
kubectl apply -k ../../k8s-manifests/testing/selenium/

echo "✅ All deployments completed!"
