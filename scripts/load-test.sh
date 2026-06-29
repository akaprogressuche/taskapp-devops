#!/bin/bash
# Load test script for demonstrating Horizontal Pod Autoscaling.
# Sends continuous traffic to the backend to push CPU above the 70% HPA threshold.
#
# Requirements: install hey with: brew install hey
# Usage: bash scripts/load-test.sh <APP_DOMAIN>
# Example: bash scripts/load-test.sh taskapp.54.12.34.56.sslip.io

set -e

DOMAIN="${1:?Usage: $0 <app-domain>}"
URL="https://${DOMAIN}/api/tasks"

echo "Starting load test against $URL"
echo "Watch HPA in another terminal with: kubectl get hpa -n taskapp -w"
echo ""

# Send 200 requests per second across 50 concurrent workers for 3 minutes
hey -z 3m -c 50 -q 200 "$URL"

echo ""
echo "Load test complete. Check final pod count with: kubectl get pods -n taskapp"
