#!/usr/bin/env bash
# =============================================================================
#  port-forward.sh — Forward local ports to Kubernetes services
#  Usage: ./scripts/port-forward.sh [namespace]
# =============================================================================
set -euo pipefail

NAMESPACE="${1:-staging}"

echo "🔌 Port-forwarding services in namespace: $NAMESPACE"
echo "   App      → http://localhost:8080"
echo "   Grafana  → http://localhost:3001"
echo "   Prometheus → http://localhost:9091"
echo ""
echo "Press Ctrl+C to stop all forwards"

# Run all port-forwards in background
kubectl port-forward svc/microapp-svc 8080:80 -n "$NAMESPACE" &
PID1=$!

kubectl port-forward svc/kube-prometheus-stack-grafana 3001:80 -n monitoring &
PID2=$!

kubectl port-forward svc/kube-prometheus-stack-prometheus 9091:9090 -n monitoring &
PID3=$!

# Cleanup on exit
trap "kill $PID1 $PID2 $PID3 2>/dev/null; echo '🛑 Port-forwards closed'" EXIT INT TERM

wait
