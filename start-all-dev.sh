#!/bin/bash

# Script to start all development environments
# Starts: db_demo (PostgreSQL), be_demo (backend), fe_demo (frontend), admin_demo (admin)
# Usage: ./start-all-dev.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting all development environments..."
echo ""

# ============================================================================
# START DATABASE
# ============================================================================

echo "📦 Starting database (db_demo)..."
if [ -f "db_demo/start-db.sh" ]; then
    cd db_demo
    ./start-db.sh
    cd ..
else
    echo "  ⚠️  db_demo/start-db.sh not found, starting manually..."
    cd db_demo
    docker-compose up -d
    cd ..
fi

echo "  ⏳ Waiting for database to be ready..."
sleep 5

# ============================================================================
# START BACKEND
# ============================================================================

echo "📦 Starting backend (be_demo)..."
# Clean up any old containers that might conflict with ports
docker rm -f be-demo-seq be-demo-api seq 2>/dev/null || true

if [ -f "be_demo/start-dev.sh" ]; then
    cd be_demo
    ./start-dev.sh > /dev/null 2>&1 &
    BACKEND_PID=$!
    echo "    ✅ Backend started (PID: $BACKEND_PID)"
    cd ..
else
    echo "  ⚠️  be_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d be-demo-dev seq-dev
fi

sleep 5

# ============================================================================
# START FRONTEND
# ============================================================================

echo "📦 Starting frontend (fe_demo)..."
if [ -f "fe_demo/start-dev.sh" ]; then
    cd fe_demo
    
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ] && [ ! -f ".yarn/cache/.gitignore" ]; then
        echo "    ⚙️  Installing dependencies..."
        yarn install
        if [ $? -ne 0 ]; then
            echo "    ❌ Failed to install dependencies!"
            cd ..
        else
            echo "    ✅ Dependencies installed!"
        fi
    fi
    
    ./start-dev.sh > /dev/null 2>&1 &
    FRONTEND_PID=$!
    echo "    ✅ Frontend started (PID: $FRONTEND_PID)"
    cd ..
else
    echo "  ⚠️  fe_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d fe-demo-dev
fi

sleep 3

# ============================================================================
# START ADMIN
# ============================================================================

echo "📦 Starting admin (admin_demo)..."
# Use docker-compose directly for admin (start-dev.sh runs tests which can be slow)
echo "    Starting with docker-compose..."
docker-compose -f docker-compose.dev.yml up -d admin-demo-dev
echo "    ✅ Admin container started"

echo ""
echo "⏳ Waiting for applications to start..."
sleep 10

# ============================================================================
# CHECK STATUS
# ============================================================================

echo ""
echo "🔍 Checking application status..."
echo ""

BACKEND_STATUS="❌"
FRONTEND_STATUS="❌"
ADMIN_STATUS="❌"
DB_STATUS="❌"

# Check database
if docker ps | grep -q postgres-dev; then
    DB_STATUS="✅"
fi

# Check backend
if curl -s http://localhost:8000/swagger > /dev/null 2>&1 || curl -s http://localhost:8000/api/oauth2/token > /dev/null 2>&1; then
    BACKEND_STATUS="✅"
fi

# Check frontend
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    FRONTEND_STATUS="✅"
fi

# Check admin
if curl -s http://localhost:8082 > /dev/null 2>&1; then
    ADMIN_STATUS="✅"
fi

echo "$DB_STATUS Database (db_demo): PostgreSQL on port 5432"
echo "$BACKEND_STATUS Backend (be_demo): http://localhost:8000"
echo "$FRONTEND_STATUS Frontend (fe_demo): http://localhost:8081"
echo "$ADMIN_STATUS Admin (admin_demo): http://localhost:8082"
echo ""

echo "📋 Application URLs:"
echo "   Database: localhost:5432"
echo "   Backend API: http://localhost:8000"
echo "   Backend Swagger: http://localhost:8000/swagger"
echo "   Frontend: http://localhost:8081"
echo "   Admin: http://localhost:8082"
echo ""

if [ "$DB_STATUS" = "✅" ] && [ "$BACKEND_STATUS" = "✅" ] && [ "$FRONTEND_STATUS" = "✅" ] && [ "$ADMIN_STATUS" = "✅" ]; then
    echo "✅ All applications are running!"
    exit 0
else
    echo "⚠️  Some applications may still be starting. Please check logs if needed."
    echo ""
    echo "💡 To check logs:"
    echo "   - Database: cd db_demo && docker-compose logs -f"
    echo "   - Backend: cd be_demo && docker-compose -f docker-compose.dev.yml logs -f be-demo-dev"
    echo "   - Frontend: cd fe_demo && docker-compose -f docker-compose.dev.yml logs -f fe-demo-dev"
    echo "   - Admin: cd admin_demo && docker-compose -f docker-compose.dev.yml logs -f admin-demo-dev"
    exit 1
fi
