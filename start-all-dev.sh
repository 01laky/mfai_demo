#!/bin/bash

# start-all-dev.sh - Script to start all development environments
# 
# This script orchestrates the startup of all development services in the correct order:
# 1. Database (PostgreSQL) - must start first as other services depend on it
# 2. Backend API (ASP.NET Core) - provides REST API and authentication
# 3. Frontend (React + Vite) - user-facing application
# 4. AI Demo (Python gRPC) - AI service with gRPC interface
# 5. Admin (React + Vite) - admin panel application
# 
# The script handles:
# - Dependency ordering (database before backend, backend before frontend/admin)
# - Port conflict resolution (removes old containers using same ports)
# - Health checks to verify services are running
# - Error handling and status reporting
# 
# Usage: ./start-all-dev.sh

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
# This allows the script to be run from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting all development environments..."
echo ""

# ============================================================================
# START DATABASE (PostgreSQL)
# ============================================================================
# Database must start first as backend depends on it for connection
# PostgreSQL runs in Docker container on port 5432

echo "📦 Starting database (db_demo)..."
if [ -f "db_demo/start-db.sh" ]; then
    # Use dedicated database startup script if available
    cd db_demo
    ./start-db.sh
    cd ..
else
    # Fallback: start database container directly using docker-compose
    echo "  ⚠️  db_demo/start-db.sh not found, starting manually..."
    cd db_demo
    docker-compose up -d
    cd ..
fi

# Wait for database to be ready before starting backend
# PostgreSQL needs a few seconds to initialize and accept connections
echo "  ⏳ Waiting for database to be ready..."
sleep 5

# ============================================================================
# START BACKEND (ASP.NET Core API)
# ============================================================================
# Backend provides REST API, authentication, and business logic
# Runs on port 8000 (HTTP) and 8001 (HTTPS)
# Also starts Seq logging server on port 5341

echo "📦 Starting backend (be_demo)..."
# Clean up any old containers that might conflict with ports
# This prevents "port already allocated" errors when restarting
# Removes containers with old naming conventions (be-demo-seq, be-demo-api)
docker rm -f be-demo-seq be-demo-api seq 2>/dev/null || true

if [ -f "be_demo/start-dev.sh" ]; then
    # Use dedicated backend startup script if available
    # Runs in background to allow script to continue
    cd be_demo
    ./start-dev.sh > /dev/null 2>&1 &
    BACKEND_PID=$!
    echo "    ✅ Backend started (PID: $BACKEND_PID)"
    cd ..
else
    # Fallback: start backend and Seq containers directly using docker-compose
    echo "  ⚠️  be_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d be-demo-dev seq-dev
fi

# Wait for backend to initialize before starting frontend/admin
# Backend needs time to start, run migrations, and be ready to accept requests
sleep 5

# ============================================================================
# START FRONTEND (React + Vite)
# ============================================================================
# Frontend is the user-facing application
# Runs on port 8081 (HTTP)
# Connects to backend API on port 8000

echo "📦 Starting frontend (fe_demo)..."
if [ -f "fe_demo/start-dev.sh" ]; then
    cd fe_demo
    
    # Check if node_modules exists, if not install dependencies
    # Yarn PnP (Plug'n'Play) uses .yarn/cache instead of node_modules
    # If neither exists, dependencies need to be installed
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
    
    # Start frontend development server in background
    ./start-dev.sh > /dev/null 2>&1 &
    FRONTEND_PID=$!
    echo "    ✅ Frontend started (PID: $FRONTEND_PID)"
    cd ..
else
    # Fallback: start frontend container directly using docker-compose
    echo "  ⚠️  fe_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d fe-demo-dev
fi

# Short wait for frontend to start
sleep 3

# ============================================================================
# START AI DEMO (Python gRPC Server)
# ============================================================================
# AI Demo provides gRPC services for AI functionality
# Runs on port 50051 (gRPC)
# Backend connects to this service for AI operations

echo "📦 Starting AI Demo (ai_demo)..."
if [ -f "ai_demo/start-dev.sh" ]; then
    # Use dedicated AI Demo startup script if available
    cd ai_demo
    ./start-dev.sh > /dev/null 2>&1 &
    AI_DEMO_PID=$!
    echo "    ✅ AI Demo started (PID: $AI_DEMO_PID)"
    cd ..
else
    # Fallback: start AI Demo container directly using docker-compose
    echo "  ⚠️  ai_demo/start-dev.sh not found, starting with docker-compose..."
    docker-compose -f docker-compose.dev.yml up -d ai-demo-dev
fi

sleep 3

# ============================================================================
# START ADMIN (React + Vite)
# ============================================================================
# Admin panel for managing users, faces, and pages
# Runs on port 8082 (HTTP)
# Connects to backend API on port 8000

echo "📦 Starting admin (admin_demo)..."
# Use docker-compose directly for admin
# Note: admin_demo/start-dev.sh runs tests which can be slow, so we bypass it
echo "    Starting with docker-compose..."
docker-compose -f docker-compose.dev.yml up -d admin-demo-dev
echo "    ✅ Admin container started"

# Wait for all applications to fully initialize
# This gives services time to start, compile, and be ready to serve requests
echo ""
echo "⏳ Waiting for applications to start..."
sleep 10

# ============================================================================
# CHECK STATUS AND HEALTH
# ============================================================================
# Verify that all services are running and accessible
# Uses Docker ps for containers and curl for HTTP endpoints

echo ""
echo "🔍 Checking application status..."
echo ""

# Initialize status variables - assume services are down until proven otherwise
BACKEND_STATUS="❌"
FRONTEND_STATUS="❌"
ADMIN_STATUS="❌"
AI_DEMO_STATUS="❌"
DB_STATUS="❌"

# Check if database container is running
# grep returns 0 (success) if postgres-dev is found in docker ps output
if docker ps | grep -q postgres-dev; then
    DB_STATUS="✅"
fi

# Check if backend API is accessible
# Try both Swagger UI and OAuth2 endpoint to verify backend is responding
if curl -s http://localhost:8000/swagger > /dev/null 2>&1 || curl -s http://localhost:8000/api/oauth2/token > /dev/null 2>&1; then
    BACKEND_STATUS="✅"
fi

# Check if frontend is accessible
# Simple HTTP GET request to verify frontend dev server is running
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    FRONTEND_STATUS="✅"
fi

# Check if admin is accessible
# Simple HTTP GET request to verify admin dev server is running
if curl -s http://localhost:8082 > /dev/null 2>&1; then
    ADMIN_STATUS="✅"
fi

# Display status summary for each service
echo "$DB_STATUS Database (db_demo): PostgreSQL on port 5432"
echo "$BACKEND_STATUS Backend (be_demo): http://localhost:8000"
echo "$FRONTEND_STATUS Frontend (fe_demo): http://localhost:8081"
echo "$ADMIN_STATUS Admin (admin_demo): http://localhost:8082"
echo ""

# Display all application URLs for easy access
echo "📋 Application URLs:"
echo "   Database: localhost:5432"
echo "   Backend API: http://localhost:8000"
echo "   Backend Swagger: http://localhost:8000/swagger"
echo "   Frontend: http://localhost:8081"
echo "   Admin: http://localhost:8082"
echo ""

# Check if all services are running successfully
# If all status variables are ✅, exit with success code (0)
# Otherwise, exit with error code (1) and provide troubleshooting tips
if [ "$DB_STATUS" = "✅" ] && [ "$BACKEND_STATUS" = "✅" ] && [ "$FRONTEND_STATUS" = "✅" ] && [ "$ADMIN_STATUS" = "✅" ] && [ "$AI_DEMO_STATUS" = "✅" ]; then
    echo "✅ All applications are running!"
    exit 0
else
    # Some services failed to start or are not accessible
    # Provide helpful commands to check logs and troubleshoot
    echo "⚠️  Some applications may still be starting. Please check logs if needed."
    echo ""
    echo "💡 To check logs:"
    echo "   - Database: cd db_demo && docker-compose logs -f"
    echo "   - Backend: cd be_demo && docker-compose -f docker-compose.dev.yml logs -f be-demo-dev"
    echo "   - Frontend: cd fe_demo && docker-compose -f docker-compose.dev.yml logs -f fe-demo-dev"
    echo "   - Admin: cd admin_demo && docker-compose -f docker-compose.dev.yml logs -f admin-demo-dev"
    echo "   - AI Demo: docker-compose -f docker-compose.dev.yml logs -f ai-demo-dev"
    exit 1
fi
