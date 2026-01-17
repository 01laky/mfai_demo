#!/bin/bash

# start-all-dev.sh - Script to start all development environments
# 
# This script orchestrates the startup of all development services in the correct order:
# 1. Database (PostgreSQL) - must start first as other services depend on it
# 2. Backend API (ASP.NET Core) - provides REST API and authentication
# 3. Frontend (React + Vite) - user-facing application
# 4. AI Demo (Python gRPC) - AI service with gRPC interface
# 5. Admin (React + Vite) - admin panel application
# 6. Logger Demo (Dozzle) - log viewer for all containers
# 
# The script handles:
# - Dependency ordering (database before backend, backend before frontend/admin)
# - Port conflict resolution (removes old containers using same ports)
# - After starting all services, displays a live status screen that refreshes every 5 seconds
# 
# Usage: ./start-all-dev.sh
# Press Ctrl+C to exit the status screen

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
# START BACKEND (ASP.NET Core API)
# ============================================================================
echo "📦 Starting backend (be_demo)..."
# Clean up any old containers that might conflict with ports
# Remove both old containers from be_demo docker-compose and root docker-compose
docker rm -f be-demo-seq be-demo-api be-demo-dev seq seq-dev 2>/dev/null || true
lsof -ti:8000,8001 | xargs kill -9 2>/dev/null || true
sleep 1

# Use root docker-compose to start backend and seq-dev together
# This ensures we use seq-dev from root docker-compose, not be-demo-seq from be_demo/docker-compose.dev.yml
echo "    Starting backend and seq with root docker-compose..."
docker-compose -f docker-compose.dev.yml up -d be-demo-dev seq > /dev/null 2>&1 &
echo "    ✅ Backend startup launched"

# ============================================================================
# START FRONTEND (React + Vite)
# ============================================================================
echo "📦 Starting frontend (fe_demo)..."
if [ -f "fe_demo/start-dev.sh" ]; then
    cd fe_demo
    ./start-dev.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Frontend startup launched"
else
    echo "  ⚠️  fe_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d fe-demo-dev > /dev/null 2>&1 &
fi

# ============================================================================
# START AI DEMO (Python gRPC Server)
# ============================================================================
echo "📦 Starting AI Demo (ai_demo)..."
if [ -f "ai_demo/start-dev.sh" ]; then
    cd ai_demo
    ./start-dev.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ AI Demo startup launched"
else
    echo "  ⚠️  ai_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d ai-demo-dev > /dev/null 2>&1 &
fi

# ============================================================================
# START LOGGER DEMO (Dozzle)
# ============================================================================
echo "📦 Starting Logger Demo (logger_demo)..."
if ! docker network ls | grep -q "mfai_demo_dev-network"; then
    docker-compose -f docker-compose.dev.yml up -d --no-deps seq > /dev/null 2>&1 || true
    sleep 1
fi

if [ -f "logger_demo/start-dev.sh" ]; then
    cd logger_demo
    ./start-dev.sh > /dev/null 2>&1 &
    cd ..
    echo "    ✅ Logger Demo startup launched"
else
    echo "  ⚠️  logger_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f logger_demo/docker-compose.dev.yml up -d dozzle-dev > /dev/null 2>&1 &
fi

# ============================================================================
# START ADMIN (React + Vite)
# ============================================================================
echo "📦 Starting admin (admin_demo)..."
docker stop be-demo-api be-demo-seq 2>/dev/null || true
docker rm -f be-demo-api be-demo-seq 2>/dev/null || true
if ! docker network ls | grep -q "mfai_demo_dev-network"; then
    docker-compose -f docker-compose.dev.yml up -d --no-deps seq > /dev/null 2>&1 || true
    sleep 1
fi
docker-compose -f docker-compose.dev.yml up -d admin-demo-dev > /dev/null 2>&1 &
echo "    ✅ Admin startup launched"

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
    clear
    echo "═══════════════════════════════════════════════════════════"
    echo "  Live Container Status (refreshing every 5 seconds)"
    echo "  Press Ctrl+C to exit"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Get current timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Last updated: $TIMESTAMP"
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
        if nc -z localhost 5432 2>/dev/null; then
            echo "  Database: ✓ Accessible"
            echo "  Port: 5432 (localhost)"
        else
            echo "  Database: ⚠ Not accessible"
            echo "  Port: 5432 (localhost)"
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
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>&1 || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  App: ✓ Accessible (http://localhost:8081)"
        else
            echo "  App: ⚠ Not accessible (http://localhost:8081)"
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
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082 2>&1 || echo "000")
        if [ "$HTTP_CODE" != "000" ] && echo "$HTTP_CODE" | grep -qE "^[234]"; then
            echo "  App: ✓ Accessible (http://localhost:8082)"
        else
            echo "  App: ⚠ Not accessible (http://localhost:8082)"
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
    
    RUNNING=$(docker ps --format '{{.Names}}' | grep -E 'postgres-dev|be-demo-dev|be-demo-api|fe-demo-dev|admin-demo-dev|seq-dev|ai-demo-dev|dozzle-dev' | wc -l | xargs)
    STOPPED=$(docker ps -a --format '{{.Names}}' | grep -E 'postgres-dev|be-demo-dev|be-demo-api|fe-demo-dev|admin-demo-dev|seq-dev|ai-demo-dev|dozzle-dev' | grep -v "$(docker ps --format '{{.Names}}')" | wc -l | xargs)
    NOT_FOUND=$((8 - RUNNING - STOPPED))
    
    echo "  Containers: $RUNNING running, $STOPPED stopped"
    echo ""
    
    echo "  Quick Links:"
    echo "    • Backend API: http://localhost:8000"
    echo "    • Swagger: http://localhost:8000/swagger/index.html"
    echo "    • Frontend: http://localhost:8081"
    echo "    • Admin: http://localhost:8082"
    echo "    • Seq Logs: http://localhost:5341"
    echo "    • Logger Demo (Dozzle): http://localhost:8080"
    echo "    • pgAdmin: http://localhost:5050"
    echo ""
    
    echo "═══════════════════════════════════════════════════════════"
    
    # Wait 5 seconds before next refresh
    sleep 5
done
