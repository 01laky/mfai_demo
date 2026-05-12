#!/bin/bash

# start-all-dev.sh - Script to start all development environments
# 
# This script orchestrates the startup of all development services in the correct order:
# 1. Database (PostgreSQL) - must start first as other services depend on it
# 2. Redis (redis_demo) - job queue for backend (optional but recommended before BE)
# 3. Backend API (ASP.NET Core) - provides REST API and authentication
# 4. Frontend (React + Vite) - user-facing application
# 5. AI Demo (Python gRPC) - AI service with gRPC interface
# 6. Admin (React + Vite) - admin panel application
# 7. Logger Demo (Dozzle) - log viewer for all containers
# 
# The script handles:
# - Dependency ordering (database before backend, backend before frontend/admin)
# - Port conflict resolution (removes old containers using same ports)
# - docker compose runs synchronously (no background &) so builds/pulls finish before the status screen
# - Live status screen until every expected container is running (not “subset == all existing”)
#
# Usage: ./scripts/start-all-dev.sh (from repository root)
# Press Ctrl+C to exit the status screen early

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

count_running_expected() {
  local c=0
  local n
  for n in "${EXPECTED_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
      c=$((c + 1))
    fi
  done
  echo "$c"
}

count_stopped_expected() {
  local c=0
  local n
  for n in "${EXPECTED_CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
      if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
        c=$((c + 1))
      fi
    fi
  done
  echo "$c"
}

echo "🚀 Starting all development environments..."
echo ""

# ============================================================================
# START DATABASE (PostgreSQL)
# ============================================================================
echo "📦 Starting database (db_demo)..."
if [ -f "db_demo/start-db.sh" ]; then
    cd db_demo
    ./start-db.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Database startup launched"
else
    echo "  ⚠️  db_demo/start-db.sh not found, starting manually..."
    cd db_demo
    docker-compose up -d > /dev/null 2>&1 &
    cd ..
fi

# ============================================================================
# START REDIS (redis_demo submodule)
# ============================================================================
echo "📦 Starting Redis (redis_demo)..."
if [ -f "redis_demo/start-redis.sh" ]; then
    cd redis_demo
    ./start-redis.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Redis startup launched"
    _expect_redis=1
else
    echo "  ⚠️  redis_demo/start-redis.sh not found, skipping Redis"
    _expect_redis=0
fi

# Full stack checklist for the status screen exit condition (redis only if we start redis_demo)
if [ "$_expect_redis" -eq 1 ]; then
    EXPECTED_CONTAINERS=(
        postgres-dev pgadmin-dev redis-dev be-demo-dev seq-dev
        fe-demo-dev fe-demo-proxy admin-demo-dev ai-demo-dev dozzle-dev
    )
else
    EXPECTED_CONTAINERS=(
        postgres-dev pgadmin-dev be-demo-dev seq-dev
        fe-demo-dev fe-demo-proxy admin-demo-dev ai-demo-dev dozzle-dev
    )
fi
EXPECTED_TOTAL=${#EXPECTED_CONTAINERS[@]}

echo "    Waiting for PostgreSQL (localhost:54320)..."
_pg_ok=0
for _i in {1..90}; do
    if nc -z localhost 54320 2>/dev/null; then
        _pg_ok=1
        echo "    ✅ PostgreSQL is accepting connections"
        break
    fi
    sleep 1
done
if [ "$_pg_ok" -eq 0 ]; then
    echo "    ⚠️  PostgreSQL not ready after 90s — backend may retry until DB is up"
fi

_redis_ok=0
if [ "$_expect_redis" -eq 1 ]; then
    echo "    Waiting for redis-dev container..."
    for _i in {1..90}; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'redis-dev'; then
            _redis_ok=1
            echo "    ✅ redis-dev is running"
            break
        fi
        sleep 1
    done
    if [ "$_redis_ok" -eq 0 ]; then
        echo "    ⚠️  redis-dev not found after 90s — ensure redis_demo is started"
    fi
fi

# ============================================================================
# START BACKEND (ASP.NET Core API)
# ============================================================================
echo "📦 Starting backend (be_demo)..."
# Clean up any old containers that might conflict with ports
# Remove both old containers from be_demo docker-compose and root docker-compose
docker rm -f be-demo-seq be-demo-api be-demo-dev seq seq-dev 2>/dev/null || true
lsof -ti:8000,8001 | xargs kill -9 2>/dev/null || true
sleep 1

# Use root docker-compose to start backend and seq-dev together (synchronous — waits for pulls/build/health)
# This ensures we use seq-dev from root docker-compose, not be-demo-seq from be_demo/docker-compose.dev.yml
echo "    Starting backend and seq with root docker-compose (this may take several minutes on first run)..."
docker-compose -f docker-compose.dev.yml up -d be-demo-dev seq
echo "    ✅ Backend + Seq containers are up (compose finished)"

# Redis (redis_demo) runs on its own bridge; BE uses hostname redis-dev on many_faces_main_dev-network.
# Compose štartuje na pozadí — opakovane čakáme na sieť + redis-dev a skúšame connect, kým to nevyjde.
echo "    Attaching redis-dev to many_faces_main_dev-network (retry until ready)..."
_redis_net_ok=0
for _i in {1..90}; do
    if ! docker network inspect many_faces_main_dev-network >/dev/null 2>&1; then
        sleep 1
        continue
    fi
    if ! docker ps --format '{{.Names}}' | grep -q '^redis-dev$'; then
        sleep 1
        continue
    fi
    _out=$(docker network connect many_faces_main_dev-network redis-dev 2>&1) || true
    if [ -z "$_out" ]; then
        _redis_net_ok=1
        echo "    ✅ redis-dev connected to dev network"
        break
    fi
    if echo "$_out" | grep -qi 'already exists'; then
        _redis_net_ok=1
        echo "    ✅ redis-dev already on dev network"
        break
    fi
    sleep 1
done
if [ "$_redis_net_ok" -eq 0 ]; then
    echo "    ⚠️  Could not attach redis-dev to many_faces_main_dev-network after 90s (is redis_demo running?)"
fi

# ============================================================================
# START FE, PROXY, ADMIN, AI (root compose — single wait; depends_on orders services)
# ============================================================================
echo "📦 Starting frontend, proxy, admin, AI (root docker-compose)..."
docker stop be-demo-api be-demo-seq 2>/dev/null || true
docker rm -f be-demo-api be-demo-seq 2>/dev/null || true
# fe-demo-proxy after fe-demo-dev; fe/admin wait on healthy be-demo-dev; ai-demo-dev is independent
docker-compose -f docker-compose.dev.yml up -d fe-demo-dev fe-demo-proxy admin-demo-dev ai-demo-dev
echo "    ✅ Frontend, proxy, admin, AI compose step finished"

# ============================================================================
# START LOGGER DEMO (Dozzle)
# ============================================================================
echo "📦 Starting Logger Demo (logger_demo)..."
if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -qE '^(many_faces_main_dev-network|mfai_demo_dev-network)$'; then
    docker-compose -f docker-compose.dev.yml up -d --no-deps seq 2>/dev/null || true
    sleep 1
fi

if [ -f "logger_demo/start-dev.sh" ]; then
    cd logger_demo
    ./start-dev.sh > /dev/null 2>&1
    cd ..
    echo "    ✅ Logger Demo startup finished (start-dev.sh)"
else
    echo "  ⚠️  logger_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f logger_demo/docker-compose.dev.yml up -d dozzle-dev
fi
echo "    ✅ Logger Demo (dozzle-dev) up"

echo ""
echo "✅ All services startup launched!"
echo ""
echo "🔄 Starting live status screen (refreshes every 5 seconds)..."
echo "   Press Ctrl+C to exit"
echo ""

# Trap Ctrl+C to exit gracefully
trap 'echo ""; echo "👋 Status screen stopped. Services continue running."; exit 0' INT TERM

# ============================================================================
# LIVE STATUS SCREEN
# ============================================================================
# Continuously refresh and display container status every 5 seconds
# This runs until the user presses Ctrl+C

while true; do
    clear 2>/dev/null || true
    echo "═══════════════════════════════════════════════════════════"
    echo "  Live Container Status (refreshing every 5 seconds)"
    echo "  Press Ctrl+C to exit"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Get current timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Last updated: $TIMESTAMP"
    
    # ========================================================================
    # CHECK AND RESTART STOPPED CONTAINERS
    # ========================================================================
    # Check for stopped containers and attempt to restart them automatically
    STOPPED=$(docker ps -a --format '{{.Names}}' --filter status=exited --filter status=created | grep -E "^(postgres-dev|be-demo-dev|be-demo-api|fe-demo-dev|fe-demo-proxy|admin-demo-dev|seq-dev|ai-demo-dev|dozzle-dev|pgadmin-dev)$" || true)
    
    if [ -n "$STOPPED" ]; then
        echo ""
        echo "🔄 Restarting stopped containers..."
        for CONTAINER in $STOPPED; do
            echo "  ⚡ Starting: $CONTAINER"
            if [ "$CONTAINER" = "dozzle-dev" ]; then
                # Dozzle can get stuck with "network not found" after dev-network recreate; remove and recreate
                docker rm -f dozzle-dev 2>/dev/null || true
                docker-compose -f logger_demo/docker-compose.dev.yml up -d dozzle-dev > /dev/null 2>&1 || true
            else
                docker start "$CONTAINER" > /dev/null 2>&1 || true
            fi
        done
        sleep 1  # Brief pause to let containers start
    fi
    
    echo ""
    
    # ========================================================================
    # DATABASE STATUS
    # ========================================================================
    echo "📦 Database (PostgreSQL)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^postgres-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=postgres-dev)
        echo "  Container: ✓ Running (postgres-dev)"
        echo "  Status: $STATUS"
        
        # Check database accessibility
        if nc -z localhost 54320 2>/dev/null; then
            echo "  Database: ✓ Accessible"
            echo "  Port: 54320 (localhost)"
        else
            echo "  Database: ⚠ Not accessible"
            echo "  Port: 54320 (localhost)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^postgres-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=postgres-dev | head -1)
        echo "  Container: ⚠ Stopped (postgres-dev)"
        echo "  Status: $STATUS"
    else
        echo "  Container: ○ Not found (postgres-dev)"
        echo "  Status: Does not exist"
    fi
    echo ""
    
    # ========================================================================
    # PGADMIN STATUS
    # ========================================================================
    echo "📦 pgAdmin (PostgreSQL Admin UI)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^pgadmin-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=pgadmin-dev)
        echo "  Container: ✓ Running (pgadmin-dev)"
        echo "  Status: $STATUS"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5050 2>&1 || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  UI: ✓ Accessible (http://localhost:5050)"
        else
            echo "  UI: ⚠ Not accessible (http://localhost:5050)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^pgadmin-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=pgadmin-dev | head -1)
        echo "  Container: ⚠ Stopped (pgadmin-dev)"
        echo "  Status: $STATUS"
        echo "  Port: 5050 (http://localhost:5050)"
    else
        echo "  Container: ○ Not found (pgadmin-dev)"
        echo "  Status: Does not exist"
        echo "  Port: 5050 (http://localhost:5050)"
    fi
    echo ""
    
    # ========================================================================
    # BACKEND STATUS
    # ========================================================================
    echo "📦 Backend API (be_demo)"
    echo "───────────────────────────────────────────────────────────"
    BACKEND_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E '^be-demo-dev$|^be-demo-api$' | head -1)
    if [ -n "$BACKEND_CONTAINER" ]; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=$BACKEND_CONTAINER)
        echo "  Container: ✓ Running ($BACKEND_CONTAINER)"
        echo "  Status: $STATUS"
        
        # Check API accessibility
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/swagger 2>&1 || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  API: ✓ Accessible (http://localhost:8000)"
        else
            echo "  API: ⚠ Not accessible (http://localhost:8000)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -E '^be-demo-dev$|^be-demo-api$' | head -1 | grep -q .; then
        STOPPED_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -E '^be-demo-dev$|^be-demo-api$' | head -1)
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=$STOPPED_CONTAINER | head -1)
        echo "  Container: ⚠ Stopped ($STOPPED_CONTAINER)"
        echo "  Status: $STATUS"
    else
        echo "  Container: ○ Not found (be-demo-dev/be-demo-api)"
        echo "  Status: Does not exist"
    fi
    echo ""
    
    # ========================================================================
    # FRONTEND STATUS
    # ========================================================================
    echo "📦 Frontend (fe_demo)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^fe-demo-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=fe-demo-dev)
        echo "  Container: ✓ Running (fe-demo-dev)"
        echo "  Status: $STATUS"
        
        FE_PAGE=$(curl -sk -m 8 https://localhost:9081/ 2>/dev/null || true)
        if echo "$FE_PAGE" | grep -qF '<!-- many-faces-fe-docker-wait-page -->'; then
            echo "  App: ⏳ Čaká sa na Vite — https://localhost:9081 sa sám obnoví (nginx wait page)"
        elif [ -n "$FE_PAGE" ]; then
            echo "  App: ✓ Accessible (https://localhost:9081 — cez fe-demo-proxy → Vite)"
        else
            echo "  App: ⚠ Not accessible (https://localhost:9081 — je spustený fe-demo-proxy?)"
        fi
        if docker ps --format '{{.Names}}' | grep -q "^fe-demo-proxy$"; then
            echo "  Proxy: ✓ Running (fe-demo-proxy)"
        else
            echo "  Proxy: ○ fe-demo-proxy not running (port 9081 nebude fungovať)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^fe-demo-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=fe-demo-dev | head -1)
        echo "  Container: ⚠ Stopped (fe-demo-dev)"
        echo "  Status: $STATUS"
    else
        echo "  Container: ○ Not found (fe-demo-dev)"
        echo "  Status: Does not exist"
    fi
    echo ""
    
    # ========================================================================
    # ADMIN STATUS
    # ========================================================================
    echo "📦 Admin (admin_demo)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^admin-demo-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=admin-demo-dev)
        echo "  Container: ✓ Running (admin-demo-dev)"
        echo "  Status: $STATUS"
        
        HTTP_CODE=$(curl -sk -m 8 -o /dev/null -w "%{http_code}" https://localhost:8082/ 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  App: ✓ Accessible (https://localhost:8082)"
        else
            echo "  App: ⚠ Not accessible (https://localhost:8082)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^admin-demo-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=admin-demo-dev | head -1)
        echo "  Container: ⚠ Stopped (admin-demo-dev)"
        echo "  Status: $STATUS"
        echo "  Port: 8082 (http://localhost:8082)"
    else
        echo "  Container: ○ Not found (admin-demo-dev)"
        echo "  Status: Does not exist"
        echo "  Port: 8082 (http://localhost:8082)"
    fi
    echo ""
    
    # ========================================================================
    # SEQ STATUS
    # ========================================================================
    echo "📦 Seq Logging Server"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^seq-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=seq-dev)
        echo "  Container: ✓ Running (seq-dev)"
        echo "  Status: $STATUS"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5341 2>&1 || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  UI: ✓ Accessible (http://localhost:5341)"
        else
            echo "  UI: ⚠ Not accessible (http://localhost:5341)"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^seq-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=seq-dev | head -1)
        echo "  Container: ⚠ Stopped (seq-dev)"
        echo "  Status: $STATUS"
    else
        echo "  Container: ○ Not found (seq-dev)"
        echo "  Status: Does not exist"
    fi
    echo ""
    
    # ========================================================================
    # AI DEMO STATUS
    # ========================================================================
    echo "📦 AI Demo (ai_demo)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^ai-demo-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=ai-demo-dev)
        echo "  Container: ✓ Running (ai-demo-dev)"
        echo "  Status: $STATUS"
        echo "  Service: ✓ Running (gRPC on port 50051)"
    elif docker ps -a --format '{{.Names}}' | grep -q "^ai-demo-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=ai-demo-dev | head -1)
        echo "  Container: ⚠ Stopped (ai-demo-dev)"
        echo "  Status: $STATUS"
    else
        echo "  Container: ○ Not found (ai-demo-dev)"
        echo "  Status: Does not exist"
    fi
    echo ""
    
    # ========================================================================
    # LOGGER DEMO STATUS
    # ========================================================================
    echo "📦 Logger Demo (logger_demo)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^dozzle-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=dozzle-dev)
        echo "  Container: ✓ Running (dozzle-dev)"
        echo "  Status: $STATUS"
        # Logger Demo (Dozzle) is considered accessible if container is running
        echo "  Service: ✓ Running (http://localhost:8080)"
    elif docker ps -a --format '{{.Names}}' | grep -q "^dozzle-dev$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter name=dozzle-dev | head -1)
        echo "  Container: ⚠ Stopped (dozzle-dev)"
        echo "  Status: $STATUS"
        echo "  Port: 8080 (http://localhost:8080)"
    else
        echo "  Container: ○ Not found (dozzle-dev)"
        echo "  Status: Does not exist"
        echo "  Port: 8080 (http://localhost:8080)"
    fi
    echo ""
    
    # ========================================================================
    # SUMMARY
    # ========================================================================
    echo "═══════════════════════════════════════════════════════════"
    echo "  Summary"
    echo "═══════════════════════════════════════════════════════════"
    
    RUNNING_EXPECTED=$(count_running_expected)
    STOPPED_EXPECTED=$(count_stopped_expected)
    
    echo "  Expected stack: $RUNNING_EXPECTED / $EXPECTED_TOTAL containers running"
    if [ "$STOPPED_EXPECTED" -gt 0 ]; then
        echo "  ⚠️  $STOPPED_EXPECTED expected container(s) exist but are not running (see sections above)"
    fi
    echo ""
    
    echo "  Quick Links:"
    echo "    • Backend API: http://localhost:8000 / https://localhost:8001"
    echo "    • Swagger: https://localhost:8001/swagger/index.html"
    echo "    • Frontend (Docker): https://localhost:9081"
    echo "    • Admin: https://localhost:8082"
    echo "    • Seq Logs: http://localhost:5341"
    echo "    • Logger Demo (Dozzle): http://localhost:8080"
    echo "    • pgAdmin: http://localhost:5050"
    echo ""
    
    echo "═══════════════════════════════════════════════════════════"
    
    # Exit only when every expected container is up and none of them are stopped/exited
    if [ "$RUNNING_EXPECTED" -eq "$EXPECTED_TOTAL" ] && [ "$STOPPED_EXPECTED" -eq 0 ]; then
        echo ""
        echo "🎉 Full stack: all $EXPECTED_TOTAL expected containers are running."
        echo "   (Apps may still be installing deps — watch FE/Admin URLs if health is starting.)"
        echo "   Services continue in the background. Status screen stopped."
        echo ""
        exit 0
    fi

    # Wait 5 seconds before next refresh
    sleep 5
done
