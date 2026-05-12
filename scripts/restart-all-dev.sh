#!/bin/bash

# Script to restart all development environments
# Stops and starts: many_faces_backend (backend), many_faces_portal (frontend), many_faces_admin (admin)

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
if [ -f "many_faces_backend/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping backend (many_faces_backend)..."
    cd many_faces_backend
    ./scripts/stop-dev.sh 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_backend/scripts/stop-dev.sh not found"
fi

# Stop frontend (many_faces_portal)
if [ -f "many_faces_portal/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping frontend (many_faces_portal)..."
    cd many_faces_portal
    ./scripts/stop-dev.sh 2>/dev/null || docker-compose down 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_portal/scripts/stop-dev.sh not found"
fi

# Stop many_faces_admin
if [ -f "many_faces_admin/scripts/stop-dev.sh" ]; then
    echo "  📦 Stopping many_faces_admin..."
    cd many_faces_admin
    ./scripts/stop-dev.sh 2>/dev/null || docker-compose down 2>/dev/null || true
    cd ..
else
    echo "  ⚠️  many_faces_admin/scripts/stop-dev.sh not found"
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
if [ -f "many_faces_backend/scripts/start-dev.sh" ]; then
    echo "  📦 Starting backend (many_faces_backend)..."
    cd many_faces_backend
    ./scripts/start-dev.sh > /dev/null 2>&1 &
    BACKEND_PID=$!
    echo "    ✅ Backend started (PID: $BACKEND_PID)"
    cd ..
else
    echo "  ⚠️  many_faces_backend/scripts/start-dev.sh not found"
fi

sleep 3

# Start frontend (many_faces_portal)
if [ -f "many_faces_portal/scripts/start-dev.sh" ]; then
    echo "  📦 Starting frontend (many_faces_portal)..."
    cd many_faces_portal || exit 1

    if [ ! -d "node_modules" ]; then
        echo "    ⚙️  Installing dependencies..."
        if ! yarn install; then
            echo "    ❌ Failed to install dependencies!"
            cd ..
        else
            echo "    ✅ Dependencies installed!"
            ./scripts/start-dev.sh > /dev/null 2>&1 &
            FRONTEND_PID=$!
            echo "    ✅ Frontend started (PID: $FRONTEND_PID)"
            cd ..
        fi
    else
        ./scripts/start-dev.sh > /dev/null 2>&1 &
        FRONTEND_PID=$!
        echo "    ✅ Frontend started (PID: $FRONTEND_PID)"
        cd ..
    fi
else
    echo "  ⚠️  many_faces_portal/scripts/start-dev.sh not found"
fi

sleep 3

# Start many_faces_admin
if [ -f "many_faces_admin/package.json" ]; then
    echo "  📦 Starting many_faces_admin..."
    cd many_faces_admin || exit 1

    if [ ! -d "node_modules" ]; then
        echo "    ⚙️  Installing dependencies..."
        if ! yarn install; then
            echo "    ❌ Failed to install dependencies!"
            cd ..
        else
            echo "    ✅ Dependencies installed!"
            export VITE_DEV_PORT=8082
            yarn dev > /dev/null 2>&1 &
            ADMIN_PID=$!
            echo "    ✅ Admin Demo started (PID: $ADMIN_PID)"
            cd ..
        fi
    else
        export VITE_DEV_PORT=8082
        yarn dev > /dev/null 2>&1 &
        ADMIN_PID=$!
        echo "    ✅ Admin Demo started (PID: $ADMIN_PID)"
        cd ..
    fi
else
    echo "  ⚠️  many_faces_admin/package.json not found"
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

echo "$BACKEND_STATUS Backend (many_faces_backend): http://localhost:8000"
echo "$FRONTEND_STATUS Frontend (many_faces_portal): http://localhost:8081"
echo "$ADMIN_STATUS Admin Demo: http://localhost:8082"
echo ""

echo "📋 Application URLs:"
echo "   Backend API: http://localhost:8000"
echo "   Backend Swagger: http://localhost:8000/swagger"
echo "   Frontend (many_faces_portal): http://localhost:8081"
echo "   Admin Demo: http://localhost:8082"
echo ""

if [ "$BACKEND_STATUS" = "✅" ] && [ "$FRONTEND_STATUS" = "✅" ] && [ "$ADMIN_STATUS" = "✅" ]; then
    echo "✅ All applications are running!"
    exit 0
else
    echo "⚠️  Some applications may still be starting. Please check logs if needed."
    echo ""
    echo "💡 To check logs:"
    echo "   - Backend: cd many_faces_backend && docker-compose logs -f"
    echo "   - Frontend: cd many_faces_portal && docker-compose logs -f"
    echo "   - Admin Demo: Check terminal or browser console"
    exit 1
fi
