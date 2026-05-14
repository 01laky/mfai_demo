#!/bin/bash

# start-all-dev.sh - Script to start all development environments
# 
# This script orchestrates the startup of all development services in the correct order:
# 1. Database (PostgreSQL) - must start first as other services depend on it
# 2. Redis (many_faces_redis) - job queue for backend (optional but recommended before BE)
# 2b. Elasticsearch (many_faces_elastic) — search index + Go search-worker (on by default; set ENABLE_ELASTICSEARCH=0 to skip)
# 3. Backend API (ASP.NET Core) - provides REST API and authentication
# 4. Frontend (React + Vite) - user-facing application
# 5. Many Faces AI service (Python gRPC) - AI service with gRPC interface
# 6. Admin (React + Vite) - admin panel application
# 7. Many Faces log viewer (Dozzle) - log viewer for all containers
# 
# The script handles:
# - Dependency ordering (database before backend, backend before frontend/admin)
# - Port conflict resolution (removes old containers using same ports)
# - docker compose runs synchronously (no background &) so builds/pulls finish before the status screen
# - Live status screen until every expected container is running (not “subset == all existing”)
#
# Usage: ./scripts/start-all-dev.sh (from repository root)
# Elasticsearch + search-worker, push-worker, and mailer-worker start by default when submodule scripts exist.
# To skip any of them: ENABLE_ELASTICSEARCH=0, ENABLE_PUSH_WORKER=0, or ENABLE_MAILER_WORKER=0.
# Push: place Firebase **service account** JSON at many_faces_push/firebase-sa.json (gitignored) or set FIREBASE_SA_HOST_PATH; PUSH_WORKER_EXPECTED_TOKEN enables gRPC metadata auth (mirrored to Push__WorkerAuthToken).
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
echo "📦 Starting database (many_faces_database)..."
if [ -f "many_faces_database/scripts/start-db.sh" ]; then
    cd many_faces_database
    ./scripts/start-db.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Database startup launched"
else
    echo "  ⚠️  many_faces_database/scripts/start-db.sh not found, starting manually..."
    cd many_faces_database
    docker-compose up -d > /dev/null 2>&1 &
    cd ..
fi

# start-db.sh / compose run asynchronously above — wait for the container before port / migrate checks.
echo "    Waiting for postgres-dev container..."
_pg_container_ok=0
for _i in $(seq 1 120); do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres-dev'; then
        _pg_container_ok=1
        echo "    ✅ postgres-dev container is present"
        break
    fi
    sleep 1
done
if [ "$_pg_container_ok" -eq 0 ]; then
    echo "    ⚠️  postgres-dev not seen after 120s — migrate step may skip or fail"
fi

# ============================================================================
# START REDIS (many_faces_redis submodule)
# ============================================================================
echo "📦 Starting Redis (many_faces_redis)..."
if [ -f "many_faces_redis/scripts/start-redis.sh" ]; then
    cd many_faces_redis
    ./scripts/start-redis.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Redis startup launched"
    _expect_redis=1
else
    echo "  ⚠️  many_faces_redis/scripts/start-redis.sh not found, skipping Redis"
    _expect_redis=0
fi

# ============================================================================
# START ELASTICSEARCH (many_faces_elastic submodule)
# ============================================================================
_expect_elastic=0
if [ "${ENABLE_ELASTICSEARCH:-1}" != "0" ] && [ -f "many_faces_elastic/scripts/start-elasticsearch.sh" ]; then
    echo "📦 Starting Elasticsearch + search-worker (many_faces_elastic)..."
    cd many_faces_elastic
    ./scripts/start-elasticsearch.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Elasticsearch + search-worker startup launched"
    _expect_elastic=1
fi

# ============================================================================
# START PUSH WORKER (many_faces_push submodule)
# ============================================================================
_expect_push=0
if [ "${ENABLE_PUSH_WORKER:-1}" != "0" ] && [ -f "many_faces_push/scripts/start-push-worker.sh" ]; then
    if [ -z "${FIREBASE_SA_HOST_PATH:-}" ] && [ -f "$ROOT/many_faces_push/firebase-sa.json" ]; then
        export FIREBASE_SA_HOST_PATH="$ROOT/many_faces_push/firebase-sa.json"
    fi
    if [ -z "${FIREBASE_SA_HOST_PATH:-}" ]; then
        echo "    ⚠️  Push worker is enabled but no Firebase service account: set FIREBASE_SA_HOST_PATH or add many_faces_push/firebase-sa.json — worker will start without FCM (SendPush → FailedPrecondition)."
    fi
    echo "📦 Starting push-worker (many_faces_push)..."
    cd many_faces_push
    ./scripts/start-push-worker.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ push-worker startup launched"
    _expect_push=1
fi

# ============================================================================
# START MAILER WORKER (many_faces_mailer submodule)
# ============================================================================
_expect_mailer=0
if [ "${ENABLE_MAILER_WORKER:-1}" != "0" ] && [ -f "many_faces_mailer/scripts/start-mailer-worker.sh" ]; then
    echo "📦 Starting mailer-worker (many_faces_mailer)..."
    cd many_faces_mailer
    ./scripts/start-mailer-worker.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ mailer-worker startup launched"
    _expect_mailer=1
fi

# Full stack checklist for the status screen exit condition (redis only if we start many_faces_redis)
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
if [ "$_expect_elastic" -eq 1 ]; then
    EXPECTED_CONTAINERS+=(elasticsearch-dev search-worker-dev)
fi
if [ "$_expect_push" -eq 1 ]; then
    EXPECTED_CONTAINERS+=(push-worker-dev)
fi
if [ "$_expect_mailer" -eq 1 ]; then
    EXPECTED_CONTAINERS+=(mailer-worker-dev)
fi
EXPECTED_TOTAL=${#EXPECTED_CONTAINERS[@]}

echo "    Waiting for PostgreSQL (localhost:54320)..."
_pg_ok=0
for _i in $(seq 1 120); do
    if nc -z localhost 54320 2>/dev/null; then
        _pg_ok=1
        echo "    ✅ PostgreSQL is accepting connections"
        break
    fi
    sleep 1
done
if [ "$_pg_ok" -eq 0 ]; then
    echo "    ⚠️  PostgreSQL not ready after 120s — backend may retry until DB is up"
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
        echo "    ⚠️  redis-dev not found after 90s — ensure many_faces_redis is started"
    fi
fi

if [ "$_expect_elastic" -eq 1 ]; then
    echo "    Waiting for Elasticsearch (localhost:59200)..."
    _es_ok=0
    for _i in {1..45}; do
        if nc -z localhost 59200 2>/dev/null; then
            _es_ok=1
            echo "    ✅ Elasticsearch HTTP port is open"
            break
        fi
        sleep 2
    done
    if [ "$_es_ok" -eq 0 ]; then
        echo "    ⚠️  Elasticsearch not ready on localhost:59200 after ~90s"
    fi
    echo "    Waiting for search-worker gRPC (localhost:59202)..."
    _sw_ok=0
    for _i in {1..45}; do
        if nc -z localhost 59202 2>/dev/null; then
            _sw_ok=1
            echo "    ✅ search-worker gRPC port is open"
            break
        fi
        sleep 2
    done
    if [ "$_sw_ok" -eq 0 ]; then
        echo "    ⚠️  search-worker not ready on localhost:59202 after ~90s"
    fi
fi

if [ "$_expect_push" -eq 1 ]; then
    echo "    Waiting for push-worker gRPC (localhost:59203)..."
    _pw_ok=0
    for _i in {1..45}; do
        if nc -z localhost 59203 2>/dev/null; then
            _pw_ok=1
            echo "    ✅ push-worker gRPC port is open"
            break
        fi
        sleep 2
    done
    if [ "$_pw_ok" -eq 0 ]; then
        echo "    ⚠️  push-worker not ready on localhost:59203 after ~90s"
    fi
fi

if [ "$_expect_mailer" -eq 1 ]; then
    echo "    Waiting for mailer-worker gRPC (localhost:59204)..."
    _mw_ok=0
    for _i in {1..45}; do
        if nc -z localhost 59204 2>/dev/null; then
            _mw_ok=1
            echo "    ✅ mailer-worker gRPC port is open"
            break
        fi
        sleep 2
    done
    if [ "$_mw_ok" -eq 0 ]; then
        echo "    ⚠️  mailer-worker not ready on localhost:59204 after ~90s"
    fi
fi

# ============================================================================
# EF MIGRATE + SQL REFERENCE SEEDS (host Postgres on 54320, before backend container)
# ============================================================================
echo "📦 EF database update + SQL reference seeds (many_faces_database)..."
if nc -z localhost 54320 2>/dev/null; then
    _conn='Host=localhost;Port=54320;Database=bedemo;Username=bedemo_user;Password=bedemo_password'
    export PATH="${PATH:+$PATH:}$HOME/.dotnet/tools"
    if (cd many_faces_backend/BeDemo.Api && dotnet ef database update --connection "$_conn"); then
        echo "    ✅ dotnet ef database update completed"
    else
        echo "    ⚠️  dotnet ef database update failed — install dotnet-ef; backend will still run Migrate on startup"
    fi
    if [ -x "many_faces_database/scripts/seed-after-migrate.sh" ]; then
        many_faces_database/scripts/seed-after-migrate.sh && echo "    ✅ SQL reference seeds applied"
    else
        echo "    ⚠️  many_faces_database/scripts/seed-after-migrate.sh missing or not executable"
    fi
else
    echo "    ⚠️  Postgres not reachable on localhost:54320 — skip migrate/seed"
fi

# When push worker is enabled, wire ASP.NET Core Push:* into be-demo-dev (see docker-compose.dev.yml ${PUSH_DEV_*}).
if [ "${ENABLE_PUSH_WORKER:-1}" != "0" ]; then
    export PUSH_DEV_ENABLED=true
    export PUSH_DEV_WORKER_GRPC_URL="${PUSH_DEV_WORKER_GRPC_URL:-http://push-worker-dev:50053}"
    if [ -n "${PUSH_WORKER_EXPECTED_TOKEN:-}" ]; then
        export PUSH_DEV_WORKER_AUTH_TOKEN="${PUSH_WORKER_EXPECTED_TOKEN}"
    fi
fi

# When mailer worker is enabled, wire Mail:* into be-demo-dev (see docker-compose.dev.yml ${MAIL_DEV_*}).
if [ "${ENABLE_MAILER_WORKER:-1}" != "0" ]; then
    export MAIL_DEV_ENABLED=true
    export MAIL_DEV_WORKER_GRPC_URL=http://mailer-worker-dev:50054
    if [ -n "${MAILER_WORKER_EXPECTED_TOKEN:-}" ]; then
        export MAIL_DEV_WORKER_AUTH_TOKEN="${MAILER_WORKER_EXPECTED_TOKEN}"
    fi
fi

# When Elasticsearch stack is enabled, wire Search:* into be-demo-dev (see docker-compose.dev.yml ${SEARCH_DEV_*}).
if [ "${ENABLE_ELASTICSEARCH:-1}" != "0" ]; then
    export SEARCH_DEV_ENABLED=true
    export SEARCH_DEV_WORKER_GRPC_URL="${SEARCH_DEV_WORKER_GRPC_URL:-http://search-worker-dev:50052}"
    if [ -n "${SEARCH_WORKER_EXPECTED_TOKEN:-}" ]; then
        export SEARCH_DEV_WORKER_AUTH_TOKEN="${SEARCH_WORKER_EXPECTED_TOKEN}"
    fi
fi

# ============================================================================
# START BACKEND (ASP.NET Core API)
# ============================================================================
echo "📦 Starting backend (many_faces_backend)..."
# Clean up any old containers that might conflict with ports
# Remove both old containers from many_faces_backend docker-compose and root docker-compose
docker rm -f be-demo-seq be-demo-api be-demo-dev seq seq-dev 2>/dev/null || true
lsof -ti:8000,8001 | xargs kill -9 2>/dev/null || true
sleep 1

# Use root docker-compose to start backend and seq-dev together (synchronous — waits for pulls/build/health)
# This ensures we use seq-dev from root docker-compose, not be-demo-seq from many_faces_backend/docker-compose.dev.yml
echo "    Starting backend and seq with root docker-compose (this may take several minutes on first run)..."
docker-compose -f docker-compose.dev.yml up -d be-demo-dev seq
echo "    ✅ Backend + Seq containers are up (compose finished)"

# Redis (many_faces_redis) runs on its own bridge; BE uses hostname redis-dev on many_faces_main_dev-network.
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
    echo "    ⚠️  Could not attach redis-dev to many_faces_main_dev-network after 90s (is many_faces_redis running?)"
fi

if [ "$_expect_elastic" -eq 1 ]; then
    echo "    Attaching elasticsearch-dev to many_faces_main_dev-network (retry until ready)..."
    _es_net_ok=0
    for _i in {1..90}; do
        if ! docker network inspect many_faces_main_dev-network >/dev/null 2>&1; then
            sleep 1
            continue
        fi
        if ! docker ps --format '{{.Names}}' | grep -q '^elasticsearch-dev$'; then
            sleep 1
            continue
        fi
        _out=$(docker network connect many_faces_main_dev-network elasticsearch-dev 2>&1) || true
        if [ -z "$_out" ]; then
            _es_net_ok=1
            echo "    ✅ elasticsearch-dev connected to dev network"
            break
        fi
        if echo "$_out" | grep -qi 'already exists'; then
            _es_net_ok=1
            echo "    ✅ elasticsearch-dev already on dev network"
            break
        fi
        sleep 1
    done
    if [ "$_es_net_ok" -eq 0 ]; then
        echo "    ⚠️  Could not attach elasticsearch-dev to many_faces_main_dev-network after 90s"
    fi
    echo "    Attaching search-worker-dev to many_faces_main_dev-network (retry until ready)..."
    _sw_net_ok=0
    for _i in {1..90}; do
        if ! docker network inspect many_faces_main_dev-network >/dev/null 2>&1; then
            sleep 1
            continue
        fi
        if ! docker ps --format '{{.Names}}' | grep -q '^search-worker-dev$'; then
            sleep 1
            continue
        fi
        _out=$(docker network connect many_faces_main_dev-network search-worker-dev 2>&1) || true
        if [ -z "$_out" ]; then
            _sw_net_ok=1
            echo "    ✅ search-worker-dev connected to dev network"
            break
        fi
        if echo "$_out" | grep -qi 'already exists'; then
            _sw_net_ok=1
            echo "    ✅ search-worker-dev already on dev network"
            break
        fi
        sleep 1
    done
    if [ "$_sw_net_ok" -eq 0 ]; then
        echo "    ⚠️  Could not attach search-worker-dev to many_faces_main_dev-network after 90s"
    fi
fi

if [ "$_expect_push" -eq 1 ]; then
    echo "    Attaching push-worker-dev to many_faces_main_dev-network (retry until ready)..."
    _pw_net_ok=0
    for _i in {1..90}; do
        if ! docker network inspect many_faces_main_dev-network >/dev/null 2>&1; then
            sleep 1
            continue
        fi
        if ! docker ps --format '{{.Names}}' | grep -q '^push-worker-dev$'; then
            sleep 1
            continue
        fi
        _out=$(docker network connect many_faces_main_dev-network push-worker-dev 2>&1) || true
        if [ -z "$_out" ]; then
            _pw_net_ok=1
            echo "    ✅ push-worker-dev connected to dev network"
            break
        fi
        if echo "$_out" | grep -qi 'already exists'; then
            _pw_net_ok=1
            echo "    ✅ push-worker-dev already on dev network"
            break
        fi
        sleep 1
    done
    if [ "$_pw_net_ok" -eq 0 ]; then
        echo "    ⚠️  Could not attach push-worker-dev to many_faces_main_dev-network after 90s"
    fi
fi

if [ "$_expect_mailer" -eq 1 ]; then
    echo "    Attaching mailer-worker-dev to many_faces_main_dev-network (retry until ready)..."
    _mw_net_ok=0
    for _i in {1..90}; do
        if ! docker network inspect many_faces_main_dev-network >/dev/null 2>&1; then
            sleep 1
            continue
        fi
        if ! docker ps --format '{{.Names}}' | grep -q '^mailer-worker-dev$'; then
            sleep 1
            continue
        fi
        _out=$(docker network connect many_faces_main_dev-network mailer-worker-dev 2>&1) || true
        if [ -z "$_out" ]; then
            _mw_net_ok=1
            echo "    ✅ mailer-worker-dev connected to dev network"
            break
        fi
        if echo "$_out" | grep -qi 'already exists'; then
            _mw_net_ok=1
            echo "    ✅ mailer-worker-dev already on dev network"
            break
        fi
        sleep 1
    done
    if [ "$_mw_net_ok" -eq 0 ]; then
        echo "    ⚠️  Could not attach mailer-worker-dev to many_faces_main_dev-network after 90s"
    fi
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
# START LOGGER (Dozzle)
# ============================================================================
echo "📦 Starting Many Faces log viewer (many_faces_logger)..."
if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -qE '^(many_faces_main_dev-network|mfai_demo_dev-network)$'; then
    docker-compose -f docker-compose.dev.yml up -d --no-deps seq 2>/dev/null || true
    sleep 1
fi

if [ -f "many_faces_logger/scripts/start-dev.sh" ]; then
    cd many_faces_logger
    ./scripts/start-dev.sh > /dev/null 2>&1
    cd ..
    echo "    ✅ Many Faces log viewer startup finished (scripts/start-dev.sh)"
else
    echo "  ⚠️  many_faces_logger/scripts/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f many_faces_logger/docker-compose.dev.yml up -d dozzle-dev
fi
echo "    ✅ Many Faces log viewer (dozzle-dev) up"

echo ""
echo "✅ All services startup launched!"
echo ""

if [ "${SKIP_STATUS_SCREEN:-}" = "1" ]; then
    echo "✅ Startup finished (SKIP_STATUS_SCREEN=1 — no live TUI). Run ./scripts/status-all.sh"
    exit 0
fi

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
    STOPPED=$(docker ps -a --format '{{.Names}}' --filter status=exited --filter status=created | grep -E "^(postgres-dev|be-demo-dev|be-demo-api|fe-demo-dev|fe-demo-proxy|admin-demo-dev|seq-dev|ai-demo-dev|dozzle-dev|pgadmin-dev|elasticsearch-dev|search-worker-dev|push-worker-dev|mailer-worker-dev|mailer-worker-tls-smoke)$" || true)
    
    if [ -n "$STOPPED" ]; then
        echo ""
        echo "🔄 Restarting stopped containers..."
        for CONTAINER in $STOPPED; do
            echo "  ⚡ Starting: $CONTAINER"
            if [ "$CONTAINER" = "dozzle-dev" ]; then
                # Dozzle can get stuck with "network not found" after dev-network recreate; remove and recreate
                docker rm -f dozzle-dev 2>/dev/null || true
                docker-compose -f many_faces_logger/docker-compose.dev.yml up -d dozzle-dev > /dev/null 2>&1 || true
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
    echo "📦 Backend API (many_faces_backend)"
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
    echo "📦 Frontend (many_faces_portal)"
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
    echo "📦 Admin (many_faces_admin)"
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
    # AI SERVICE STATUS
    # ========================================================================
    echo "📦 Many Faces AI service (many_faces_ai)"
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
    # LOGGER (Dozzle) STATUS
    # ========================================================================
    echo "📦 Many Faces log viewer (many_faces_logger)"
    echo "───────────────────────────────────────────────────────────"
    if docker ps --format '{{.Names}}' | grep -q "^dozzle-dev$"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter name=dozzle-dev)
        echo "  Container: ✓ Running (dozzle-dev)"
        echo "  Status: $STATUS"
        # Many Faces log viewer (Dozzle) is considered accessible if container is running
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
    echo "    • Many Faces log viewer (Dozzle): http://localhost:8080"
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
