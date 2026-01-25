#!/bin/bash
BACKUP_DIR="/tmp/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

echo "📦 Backing up etcd..."
kubectl -n kube-system exec -it etcd-cp-01 -- sh -c \
  "ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup-${TIMESTAMP}.db"

kubectl -n kube-system cp etcd-cp-01:/tmp/etcd-backup-${TIMESTAMP}.db \
  ${BACKUP_DIR}/etcd-backup-${TIMESTAMP}.db

echo "✅ Backup saved to: ${BACKUP_DIR}/etcd-backup-${TIMESTAMP}.db"
