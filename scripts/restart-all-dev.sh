#!/bin/bash

# Script to restart all development environments
# Stops and starts: be_demo (backend), fe_demo (frontend), admin_demo (admin)

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🔄 Restarting all development environments..."
echo ""

# ============================================================================
# STOP ALL APPLICATIONS
# ============================================================================

echo "🛑 Stopping all applications..."
echo ""

# Stop backend
if [ -f "be_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping backend (be_demo)..."
    cd be_demo
    ./stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  be_demo/stop-dev.sh not found"
fi

# Stop frontend (fe_demo)
if [ -f "fe_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping frontend (fe_demo)..."
    cd fe_demo
    ./stop-dev.sh 2>/dev/null || docker-compose down 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  fe_demo/stop-dev.sh not found"
fi

# Stop admin_demo
if [ -f "admin_demo/stop-dev.sh" ]; then
    echo "  📦 Stopping admin_demo..."
    cd admin_demo
    ./stop-dev.sh 2>/dev/null || docker-compose down 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  admin_demo/stop-dev.sh not found"
fi

# Kill any remaining processes
echo "  🧹 Cleaning up remaining processes..."
pkill -f "vite.*8081" 2>/dev/null || true
pkill -f "vite.*8082" 2>/dev/null || true
pkill -f "dotnet.*BeDemo" 2>/dev/null || true

sleep 2

echo "✅ All applications stopped"
echo ""

# ============================================================================
# START ALL APPLICATIONS
# ============================================================================

echo "🚀 Starting all applications..."
echo ""

# Start backend
if [ -f "be_demo/start-dev.sh" ]; then
    echo "  📦 Starting backend (be_demo)..."
    cd be_demo
    ./start-dev.sh > /dev/null 2>&1 &
    BACKEND_PID=$!
    echo "    ✅ Backend started (PID: $BACKEND_PID)"
    cd ..
else
    echo "  ⚠️  be_demo/start-dev.sh not found"
fi

sleep 3

# Start frontend (fe_demo)
if [ -f "fe_demo/start-dev.sh" ]; then
    echo "  📦 Starting frontend (fe_demo)..."
    cd fe_demo
    
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ]; then
        echo "    ⚙️  Installing dependencies..."
        yarn install
        if [ $? -ne 0 ]; then
            echo "    ❌ Failed to install dependencies!"
            cd ..
            continue
        fi
        echo "    ✅ Dependencies installed!"
    fi
    
    ./start-dev.sh > /dev/null 2>&1 &
    FRONTEND_PID=$!
    echo "    ✅ Frontend started (PID: $FRONTEND_PID)"
    cd ..
else
    echo "  ⚠️  fe_demo/start-dev.sh not found"
fi

sleep 3

# Start admin_demo
if [ -f "admin_demo/package.json" ]; then
    echo "  📦 Starting admin_demo..."
    cd admin_demo
    
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ]; then
        echo "    ⚙️  Installing dependencies..."
        yarn install
        if [ $? -ne 0 ]; then
            echo "    ❌ Failed to install dependencies!"
            cd ..
            continue
        fi
        echo "    ✅ Dependencies installed!"
    fi
    
    export VITE_DEV_PORT=8082
    yarn dev > /dev/null 2>&1 &
    ADMIN_PID=$!
    echo "    ✅ Admin Demo started (PID: $ADMIN_PID)"
    cd ..
else
    echo "  ⚠️  admin_demo/package.json not found"
fi

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

if curl -s http://localhost:8000/swagger > /dev/null 2>&1; then
    BACKEND_STATUS="✅"
fi

if curl -s http://localhost:8081 > /dev/null 2>&1; then
    FRONTEND_STATUS="✅"
fi

if curl -s http://localhost:8082 > /dev/null 2>&1; then
    ADMIN_STATUS="✅"
fi

echo "$BACKEND_STATUS Backend (be_demo): http://localhost:8000"
echo "$FRONTEND_STATUS Frontend (fe_demo): http://localhost:8081"
echo "$ADMIN_STATUS Admin Demo: http://localhost:8082"
echo ""

echo "📋 Application URLs:"
echo "   Backend API: http://localhost:8000"
echo "   Backend Swagger: http://localhost:8000/swagger"
echo "   Frontend (fe_demo): http://localhost:8081"
echo "   Admin Demo: http://localhost:8082"
echo ""

if [ "$BACKEND_STATUS" = "✅" ] && [ "$FRONTEND_STATUS" = "✅" ] && [ "$ADMIN_STATUS" = "✅" ]; then
    echo "✅ All applications are running!"
    exit 0
else
    echo "⚠️  Some applications may still be starting. Please check logs if needed."
    echo ""
    echo "💡 To check logs:"
    echo "   - Backend: cd be_demo && docker-compose logs -f"
    echo "   - Frontend: cd fe_demo && docker-compose logs -f"
    echo "   - Admin Demo: Check terminal or browser console"
    exit 1
fi
