#!/bin/bash
echo "Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo "Applying MetalLB configuration..."
kubectl apply -f ipaddresspool.yaml
kubectl apply -f l2advertisement.yaml

echo "✅ MetalLB installed successfully"
