#!/bin/bash
# =============================================================================
# Firewall: Block container access to dangerous host services
# =============================================================================
# The container has full internet access by default (Docker networking).
# This script ONLY adds rules to block access to sensitive ports on the
# Docker host, preventing the container from reaching host databases,
# Docker API, admin panels, etc.
# =============================================================================

set -euo pipefail

echo "=== Configuring firewall ==="

# Get host gateway IP (this is the Docker host)
HOST_IP=$(ip route | grep default | awk '{print $3}')
echo "Host gateway IP: $HOST_IP"

# Block dangerous ports on the Docker host
BLOCKED_PORTS=(
    2375  # Docker API (HTTP)
    2376  # Docker API (HTTPS)
    4243  # Docker legacy API
    5000  # Docker Registry
    5432  # PostgreSQL
    3306  # MySQL
    6379  # Redis
    27017 # MongoDB
    9200  # Elasticsearch
    8080  # Common dev server / admin
    8443  # Common HTTPS admin
    9090  # Prometheus
)

for port in "${BLOCKED_PORTS[@]}"; do
    iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport "$port" -j REJECT --reject-with icmp-port-unreachable
done

# Also block via host.docker.internal if it resolves
if HOST_DOCKER_IP=$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1}'); then
    if [ -n "$HOST_DOCKER_IP" ] && [ "$HOST_DOCKER_IP" != "$HOST_IP" ]; then
        for port in "${BLOCKED_PORTS[@]}"; do
            iptables -A OUTPUT -d "$HOST_DOCKER_IP" -p tcp --dport "$port" -j REJECT --reject-with icmp-port-unreachable
        done
        echo "Also blocked ports via host.docker.internal ($HOST_DOCKER_IP)"
    fi
fi

echo "Blocked ${#BLOCKED_PORTS[@]} dangerous ports on host"

# --- Verification ---
echo "=== Running verification tests ==="

# Test 1: Internet access (retry up to 3 times, network may not be ready)
INTERNET_OK=false
for i in 1 2 3; do
    if curl -sf --max-time 5 https://google.com > /dev/null 2>&1; then
        INTERNET_OK=true
        break
    fi
    echo "  Internet test attempt $i failed, retrying in 2s..."
    sleep 2
done

if [ "$INTERNET_OK" = true ]; then
    echo "[PASS] Internet access works"
else
    echo "[WARN] Internet access test failed (may work after container fully starts)"
fi

# Test 2: Host dangerous ports should be blocked
if curl -sf --max-time 3 "http://$HOST_IP:2375/version" > /dev/null 2>&1; then
    echo "[WARN] Docker API on host is reachable (should be blocked)"
else
    echo "[PASS] Docker API on host is blocked"
fi

echo "=== Firewall configured ==="
