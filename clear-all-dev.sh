#!/bin/bash

# Script to completely remove all development containers and volumes
# Stops and removes: db_demo (PostgreSQL), be_demo (backend), fe_demo (frontend), admin_demo (admin), seq
# Usage: ./clear-all-dev.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧹 Clearing all development containers and volumes..."
echo ""
echo "⚠️  WARNING: This will completely remove all containers and volumes!"
echo "   All data will be lost (including database data)!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

echo "🧹 Starting cleanup..."
echo ""

# ============================================================================
# CLEAR ALL APPLICATIONS
# ============================================================================

# Clear backend (be_demo)
if [ -f "be_demo/clear-dev.sh" ]; then
    echo "  📦 Clearing backend (be_demo)..."
    cd be_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  be_demo/clear-dev.sh not found, clearing manually..."
    docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
    docker rm -f be-demo-dev seq-dev 2>/dev/null || true
    docker volume rm be-demo-https be-demo-data 2>/dev/null || true
fi

# Clear frontend (fe_demo)
if [ -f "fe_demo/clear-dev.sh" ]; then
    echo "  📦 Clearing frontend (fe_demo)..."
    cd fe_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  fe_demo/clear-dev.sh not found, clearing manually..."
    docker-compose -f docker-compose.dev.yml stop fe-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f fe-demo-dev 2>/dev/null || true
    docker rm -f fe-demo-dev 2>/dev/null || true
    docker volume rm fe-demo-node-modules fe-demo-yarn-cache 2>/dev/null || true
fi

# Clear admin_demo
if [ -f "admin_demo/clear-dev.sh" ]; then
    echo "  📦 Clearing admin (admin_demo)..."
    cd admin_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  admin_demo/clear-dev.sh not found, clearing manually..."
    docker-compose -f docker-compose.dev.yml stop admin-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f admin-demo-dev 2>/dev/null || true
    docker rm -f admin-demo-dev 2>/dev/null || true
    docker volume rm admin-demo-node-modules admin-demo-yarn-cache 2>/dev/null || true
fi

# Clear database (db_demo)
if [ -f "db_demo/clear-db.sh" ]; then
    echo "  📦 Clearing database (db_demo)..."
    cd db_demo
    ./clear-db.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  db_demo/clear-db.sh not found, clearing manually..."
    cd db_demo
    docker-compose down -v 2>/dev/null || true
    docker rm -f postgres-dev 2>/dev/null || true
    docker volume rm postgres-data 2>/dev/null || true
    cd ..
fi

# Clear all remaining containers from docker-compose.dev.yml
echo "  🧹 Clearing remaining containers from docker-compose.dev.yml..."
docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true

# Remove all containers by name
echo "  🧹 Removing containers by name..."
docker rm -f be-demo-dev fe-demo-dev admin-demo-dev postgres-dev seq-dev 2>/dev/null || true

# Remove all volumes
echo "  🧹 Removing all volumes..."
docker volume rm be-demo-https be-demo-data seq-data 2>/dev/null || true
docker volume rm fe-demo-node-modules fe-demo-yarn-cache 2>/dev/null || true
docker volume rm admin-demo-node-modules admin-demo-yarn-cache 2>/dev/null || true
docker volume rm postgres-data 2>/dev/null || true

# Remove network
echo "  🧹 Removing network..."
docker network rm dev-network 2>/dev/null || true

# Kill any remaining processes (fallback)
echo "  🧹 Cleaning up remaining processes..."
pkill -f "vite.*8081" 2>/dev/null || true
pkill -f "vite.*8082" 2>/dev/null || true
pkill -f "dotnet.*BeDemo" 2>/dev/null || true

sleep 2

echo ""
echo "✅ All containers and volumes cleared"
echo ""

# ============================================================================
# VERIFY STATUS
# ============================================================================

echo "🔍 Verifying cleanup..."
echo ""

# Check if containers are still running
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "be-demo-dev|fe-demo-dev|admin-demo-dev|postgres-dev|seq-dev" || true)

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "✅ All containers removed"
else
    echo "⚠️  Some containers are still running:"
    echo "$RUNNING_CONTAINERS"
    echo ""
    echo "💡 To force remove, run:"
    echo "   docker rm -f $RUNNING_CONTAINERS"
fi

# Check volumes
REMAINING_VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "be-demo|fe-demo|admin-demo|postgres-data|seq-data" || true)

if [ -z "$REMAINING_VOLUMES" ]; then
    echo "✅ All volumes removed"
else
    echo "⚠️  Some volumes still exist:"
    echo "$REMAINING_VOLUMES"
    echo ""
    echo "💡 To remove volumes, run:"
    echo "   docker volume rm $REMAINING_VOLUMES"
fi

echo ""
echo "🎉 Cleanup complete!"
