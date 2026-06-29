#!/bin/bash
# Failover demonstration script for the viva.
# Drains a worker node to simulate failure, verifies the app stays up,
# then brings the node back.
#
# Usage: bash scripts/failover-demo.sh <worker-node-name>
# Find node names with: kubectl get nodes

set -e

NODE="${1:?Usage: $0 <node-name>}"

echo "=== Before drain ==="
kubectl get nodes
echo ""
kubectl get pods -n taskapp -o wide
echo ""

echo "=== Draining node: $NODE ==="
echo "This evicts all pods from the node. PodDisruptionBudgets keep at least 1 replica alive."
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --grace-period=30

echo ""
echo "=== Pod distribution after drain ==="
kubectl get pods -n taskapp -o wide

echo ""
echo "=== Testing app is still reachable ==="
DOMAIN="${2:-$(kubectl get ingress taskapp-ingress -n taskapp -o jsonpath='{.spec.rules[0].host}')}"
HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://${DOMAIN}/api/tasks" || true)
echo "HTTP status from app: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
  echo "App is UP during node failure."
else
  echo "Warning: got HTTP $HTTP_STATUS, check app logs."
fi

echo ""
echo "=== Bringing node back online ==="
kubectl uncordon "$NODE"

echo ""
echo "=== Final cluster state ==="
kubectl get nodes
kubectl get pods -n taskapp -o wide
