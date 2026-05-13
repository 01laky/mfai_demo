#!/bin/bash

# Script to stop all development environments
# Stops: logger, apps, many_faces_redis (Redis), many_faces_database (PostgreSQL), root compose
# Usage: ./scripts/stop-all-dev.sh (from repository root)

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🛑 Stopping all development environments..."
echo ""

# ============================================================================
# STOP LOGGER (Dozzle)
# ============================================================================
echo "📦 Stopping Many Faces log viewer (many_faces_logger)..."
if [ -f "many_faces_logger/scripts/stop-dev.sh" ]; then
    cd many_faces_logger
    ./scripts/stop-dev.sh > /dev/null 2>&1
    cd ..
else
    docker-compose -f many_faces_logger/docker-compose.dev.yml stop 2>/dev/null || true
fi
echo "    ✅ Many Faces log viewer stopped"
echo ""

# ============================================================================
# STOP ALL APPLICATIONS
# ============================================================================

# Stop backend (many_faces_backend)
if [ -f "many_faces_backend/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping backend (many_faces_backend)..."
    cd many_faces_backend
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_backend/scripts/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop be-demo-dev seq-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f be-demo-dev seq-dev 2>/dev/null || true
fi

# Stop frontend (many_faces_portal)
if [ -f "many_faces_portal/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping frontend (many_faces_portal)..."
    cd many_faces_portal
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_portal/scripts/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop fe-demo-dev fe-demo-proxy 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f fe-demo-dev fe-demo-proxy 2>/dev/null || true
fi

# Stop many_faces_admin
if [ -f "many_faces_admin/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping admin (many_faces_admin)..."
    cd many_faces_admin
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_admin/scripts/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop admin-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f admin-demo-dev 2>/dev/null || true
fi

# Stop Many Faces AI service (many_faces_ai)
if [ -f "many_faces_ai/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping Many Faces AI service (many_faces_ai)..."
    cd many_faces_ai
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_ai/scripts/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f docker-compose.dev.yml stop ai-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f ai-demo-dev 2>/dev/null || true
fi

# Stop Many Faces log viewer (many_faces_logger)
if [ -f "many_faces_logger/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping Many Faces log viewer (many_faces_logger)..."
    cd many_faces_logger
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_logger/scripts/stop-dev.sh not found, trying docker-compose directly..."
    docker-compose -f many_faces_logger/docker-compose.dev.yml stop dozzle-dev 2>/dev/null || true
    docker-compose -f many_faces_logger/docker-compose.dev.yml rm -f dozzle-dev 2>/dev/null || true
fi

# Stop Elasticsearch (many_faces_elastic)
if [ -f "many_faces_elastic/scripts/stop-elasticsearch.sh" ]; then
    echo "  📦 Stopping Elasticsearch + search-worker (many_faces_elastic)..."
    cd many_faces_elastic
    ./scripts/stop-elasticsearch.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_elastic/scripts/stop-elasticsearch.sh not found, trying docker compose directly..."
    (cd many_faces_elastic 2>/dev/null && docker compose down 2>/dev/null) || true
fi

# Stop Redis (many_faces_redis)
if [ -f "many_faces_redis/scripts/stop-redis.sh" ]; then
    echo "  📦 Stopping Redis (many_faces_redis)..."
    cd many_faces_redis
    ./scripts/stop-redis.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_redis/scripts/stop-redis.sh not found, trying docker-compose directly..."
    cd many_faces_redis 2>/dev/null && docker-compose down 2>/dev/null || true
    cd "$ROOT" 2>/dev/null || true
fi

# Stop database (many_faces_database)
if [ -f "many_faces_database/scripts/stop-db.sh" ]; then
    echo "  📦 Stopping database (many_faces_database)..."
    cd many_faces_database
    ./scripts/stop-db.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_database/scripts/stop-db.sh not found, trying docker-compose directly..."
    cd many_faces_database
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
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "be-demo-dev|fe-demo-dev|fe-demo-proxy|admin-demo-dev|ai-demo-dev|postgres-dev|pgadmin-dev|redis-dev|seq-dev|dozzle-dev|elasticsearch-dev|search-worker-dev" || true)

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "⚠️  Some containers still running — force-stopping:"
    echo "$RUNNING_CONTAINERS"
    # shellcheck disable=SC2086
    docker stop $RUNNING_CONTAINERS 2>/dev/null || true
    sleep 2
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "be-demo-dev|fe-demo-dev|fe-demo-proxy|admin-demo-dev|ai-demo-dev|postgres-dev|pgadmin-dev|redis-dev|seq-dev|dozzle-dev|elasticsearch-dev|search-worker-dev" || true)
fi

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "✅ All containers are stopped"
    exit 0
else
    echo "❌ Containers still running after force-stop:"
    echo "$RUNNING_CONTAINERS"
    echo ""
    echo "💡 Try: docker stop $RUNNING_CONTAINERS"
    exit 1
fi
