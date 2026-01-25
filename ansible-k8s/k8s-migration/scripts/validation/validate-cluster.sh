#!/bin/bash

echo "🔍 Validating Kubernetes Cluster..."

echo ""
echo "=== Node Status ==="
kubectl get nodes -o wide

echo ""
echo "=== Pod Status (All Namespaces) ==="
kubectl get pods -A | grep -v Running | grep -v Completed || echo "✅ All pods running"

echo ""
echo "=== Storage Status ==="
kubectl get storageclass
kubectl get pv
kubectl get pvc -A

echo ""
echo "=== Ingress Status ==="
kubectl -n ingress-nginx get svc
kubectl get ingress -A

echo ""
echo "=== Application Health ==="
echo "Flask API:"
kubectl -n flask-app get pods -o wide
echo ""
echo "Monitoring:"
kubectl -n monitoring get pods | grep -E 'prometheus|grafana|alertmanager'
echo ""
echo "Testing:"
kubectl -n testing get pods

echo ""
echo "✅ Validation complete"
