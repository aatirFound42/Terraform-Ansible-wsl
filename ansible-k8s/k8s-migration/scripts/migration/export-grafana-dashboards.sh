#!/bin/bash
# Export dashboards from old Grafana instance

OLD_GRAFANA="http://192.168.56.16:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
OUTPUT_DIR="./exported-dashboards"

mkdir -p $OUTPUT_DIR

echo "📊 Exporting Grafana dashboards..."

curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} ${OLD_GRAFANA}/api/search | \
  jq -r '.[] | select(.type == "dash-db") | .uid' | \
  while read uid; do
    echo "Exporting dashboard: $uid"
    curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} \
      "${OLD_GRAFANA}/api/dashboards/uid/${uid}" | \
      jq '.dashboard' > "${OUTPUT_DIR}/dashboard-${uid}.json"
  done

echo "✅ Dashboards exported to: $OUTPUT_DIR"
