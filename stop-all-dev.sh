#!/bin/bash

# Script to stop all development environments
# Stops: db_demo (PostgreSQL), be_demo (backend), fe_demo (frontend), admin_demo (admin)
# Usage: ./stop-all-dev.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛑 Stopping all development environments..."
echo ""

# ============================================================================
# STOP ALL APPLICATIONS
# ============================================================================

# Stop backend (be_demo)
if [ -f "be_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping backend (be_demo)..."
    cd be_demo
    ./stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  be_demo/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop be-demo-dev seq-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f be-demo-dev seq-dev 2>/dev/null || true
fi

# Stop frontend (fe_demo)
if [ -f "fe_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping frontend (fe_demo)..."
    cd fe_demo
    ./stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  fe_demo/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop fe-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f fe-demo-dev 2>/dev/null || true
fi

# Stop admin_demo
if [ -f "admin_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping admin (admin_demo)..."
    cd admin_demo
    ./stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  admin_demo/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop admin-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f admin-demo-dev 2>/dev/null || true
fi

# Stop database (db_demo)
if [ -f "db_demo/stop-db.sh" ]; then
    echo "  📦 Stopping database (db_demo)..."
    cd db_demo
    ./stop-db.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  db_demo/stop-db.sh not found, trying docker-compose directly..."
    cd db_demo
    docker-compose down 2>/dev/null || true
    cd ..
fi

# Stop all remaining containers from docker-compose.dev.yml
echo "  🧹 Stopping remaining containers from docker-compose.dev.yml..."
docker-compose -f docker-compose.dev.yml stop 2>/dev/null || true
docker-compose -f docker-compose.dev.yml rm -f 2>/dev/null || true

# Kill any remaining processes (fallback)
echo "  🧹 Cleaning up remaining processes..."
pkill -f "vite.*8081" 2>/dev/null || true
pkill -f "vite.*8082" 2>/dev/null || true
pkill -f "dotnet.*BeDemo" 2>/dev/null || true

sleep 2

echo ""
echo "✅ All applications stopped"
echo ""

# ============================================================================
# VERIFY STATUS
# ============================================================================

echo "🔍 Verifying containers are stopped..."
echo ""

# Check if containers are still running
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "be-demo-dev|fe-demo-dev|admin-demo-dev|postgres-dev|seq-dev" || true)

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "✅ All containers are stopped"
    exit 0
else
    echo "⚠️  Some containers are still running:"
    echo "$RUNNING_CONTAINERS"
    echo ""
    echo "💡 To force stop, run:"
    echo "   docker stop $RUNNING_CONTAINERS"
    exit 1
fi
