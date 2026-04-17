#!/usr/bin/env bash
# =============================================================================
#  rollback.sh — Emergency rollback to previous deployment
#  Usage: ./scripts/rollback.sh <namespace> [revision]
# =============================================================================
set -euo pipefail

NAMESPACE="${1:-production}"
REVISION="${2:-}"
DEPLOYMENT="microapp"

echo "🔄 Rolling back deployment/$DEPLOYMENT in namespace: $NAMESPACE"

if [[ -n "$REVISION" ]]; then
  kubectl rollout undo deployment/"$DEPLOYMENT" \
    --namespace="$NAMESPACE" \
    --to-revision="$REVISION"
else
  kubectl rollout undo deployment/"$DEPLOYMENT" \
    --namespace="$NAMESPACE"
fi

kubectl rollout status deployment/"$DEPLOYMENT" \
  --namespace="$NAMESPACE" \
  --timeout=300s

echo "✅ Rollback complete"
kubectl get pods -n "$NAMESPACE" -l app=microapp
